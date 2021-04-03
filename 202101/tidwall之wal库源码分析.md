# tidwall/wal库源码分析

## 1.tidwall/wal库数据存储架构

下图将详细分析了tidwall/wal库中核心的数据组织存储结构，不得不说，这种设计还是非常高效巧妙的

![](./imgs/tidwall-wal内部数据存储结构.jpg)

## 2.tidwall/wal库代码思维导图

![](./imgs/tidwall-wal源码分析.png)


## 3.tidwall/wal核心数据结构

### 3.1 Options配置

```go
// Options for Log
type Options struct {
	// NoSync disables fsync after writes. This is less durable and puts the
	// log at risk of data loss when there's a server crash.
	NoSync bool
	// SegmentSize of each segment. This is just a target value, actual size
	// may differ. Default is 20 MB.
  // 每个segment的目标大小20M,实际值可能会有些偏差
	SegmentSize int
	// LogFormat is the format of the log files. Default is Binary.
	LogFormat LogFormat
	// SegmentCacheSize is the maximum number of segments that will be held in
	// memory for caching. Increasing this value may enhance performance for
	// concurrent read operations. Default is 1
	// 缓存的segment的最大个数 
	SegmentCacheSize int
	// NoCopy allows for the Read() operation to return the raw underlying data
	// slice. This is an optimization to help minimize allocations. When this
	// option is set, do not modify the returned data because it may affect
	// other Read calls. Default false
	// 在读时是否拷贝一份数据返回给client，默认false 
	NoCopy bool
}

// DefaultOptions for Open().
var DefaultOptions = &Options{
	NoSync:           false,    // Fsync after every write
	SegmentSize:      20971520, // 20 MB log segment files.
	LogFormat:        Binary,   // Binary format is small and fast.
	SegmentCacheSize: 2,        // Number of cached in-memory segments
	NoCopy:           false,    // Make a new copy of data for every Read call.
}
```

### 3.2 Log结构

```go
// Log represents a write ahead log
type Log struct {
	mu         sync.RWMutex
	path       string      // absolute path to log directory
	opts       Options     // log options
	closed     bool        // log is closed
	corrupt    bool        // log may be corrupt
	segments   []*segment  // all known log segments
	firstIndex uint64      // index of the first entry in log
	lastIndex  uint64      // index of the last entry in log
	sfile      *os.File    // tail segment file handle
	wbatch     Batch       // reusable write batch
	scache     tinylru.LRU // segment entries cache
}

```

### 3.3 segment结构

```go
// segment represents a single segment file.
type segment struct {
	path  string // path of segment file
	index uint64 // first index of segment
	ebuf  []byte // cached entries buffer，该segment实际的数据
	epos  []bpos // cached entries positions in buffer，该segment数据的索引
    // 对于其中存储的一条日志条目来说，假设其在epos中的位置为i，则其对应的数据的起始下标和结束下标分别为start=epos[i].pos,end=epos[i].end,
    // 因此最终的数据为 data=ebuf[start:end]  
    
}

type bpos struct {
	pos int // byte position
	end int // one byte past pos
}
```

### 3.4 Batch 和 batchEntry 结构

```go
// Batch of entries. Used to write multiple entries at once using WriteBatch().
type Batch struct {
	entries []batchEntry
	datas   []byte
}

type batchEntry struct {
	index uint64
	size  int
}

// Write an entry to the batch
func (b *Batch) Write(index uint64, data []byte) {
	b.entries = append(b.entries, batchEntry{index, len(data)})
	b.datas = append(b.datas, data...)
}

// Clear the batch for reuse.
func (b *Batch) Clear() {
	b.entries = b.entries[:0]
	b.datas = b.datas[:0]
}
```


## 4. Open函数的源码分析

```go
// Open a new write ahead log
func Open(path string, opts *Options) (*Log, error) {
	if opts == nil {
		opts = DefaultOptions
	}
	if opts.SegmentCacheSize <= 0 {
		opts.SegmentCacheSize = DefaultOptions.SegmentCacheSize
	}
	if opts.SegmentSize <= 0 {
		opts.SegmentSize = DefaultOptions.SegmentSize
	}
	var err error
	path, err = abs(path)
	if err != nil {
		return nil, err
	}
    // 设置cache和初始化Log
	l := &Log{path: path, opts: *opts}
	l.scache.Resize(l.opts.SegmentCacheSize)
	if err := os.MkdirAll(path, 0777); err != nil {
		return nil, err
	}
    // 加载之前的数据
	if err := l.load(); err != nil {
		return nil, err
	}
	return l, nil
}

```
```go
// load all the segments. This operation also cleans up any START/END segments.
func (l *Log) load() error {
    // 读取所有的文件列表
	fis, err := ioutil.ReadDir(l.path)
	if err != nil {
		return err
	}
	startIdx := -1
	endIdx := -1
    // 遍历
	for _, fi := range fis {
		name := fi.Name()
		if fi.IsDir() || len(name) < 20 {
            // 非法的文件
			continue
		}
		index, err := strconv.ParseUint(name[:20], 10, 64)
		if err != nil || index == 0 {
			continue
		}
		isStart := len(name) == 26 && strings.HasSuffix(name, ".START")
		isEnd := len(name) == 24 && strings.HasSuffix(name, ".END")
		if len(name) == 20 || isStart || isEnd {
			if isStart {
                // startIdx要取最大的一个，所以一直赋值
				startIdx = len(l.segments)
			} else if isEnd && endIdx == -1 {
                // endIdx要取最小的一个
				endIdx = len(l.segments)
			}
            // 先全部恢复
			l.segments = append(l.segments, &segment{
				index: index,
				path:  filepath.Join(l.path, name),
			})
		}
	}
	// 如果没有加载到数据，新初始化
	if len(l.segments) == 0 {
		// Create a new log
		l.segments = append(l.segments, &segment{
			index: 1,
			path:  filepath.Join(l.path, segmentName(1)),
		})
		l.firstIndex = 1
		l.lastIndex = 0
		l.sfile, err = os.Create(l.segments[0].path)
		return err
	}
	// 有读到数据，执行下面的逻辑，并且之前存在截取的文件时，先完成截取逻辑
	// Open existing log. Clean up log if START of END segments exists.
	if startIdx != -1 {
		if endIdx != -1 {
			// There should not be a START and END at the same time
			return ErrCorrupt
		}
		// 从头开始删除到startIndex的数据
		// Delete all files leading up to START
		for i := 0; i < startIdx; i++ {
			if err := os.Remove(l.segments[i].path); err != nil {
				return err
			}
		}
		l.segments = append([]*segment{}, l.segments[startIdx:]...)
		// Rename the START segment
		orgPath := l.segments[0].path
		finalPath := orgPath[:len(orgPath)-len(".START")]
		err := os.Rename(orgPath, finalPath)
		if err != nil {
			return err
		}
		l.segments[0].path = finalPath
	}
	// 从后往前删除
	if endIdx != -1 {
		// Delete all files following END
		for i := len(l.segments) - 1; i > endIdx; i-- {
			if err := os.Remove(l.segments[i].path); err != nil {
				return err
			}
		}
		l.segments = append([]*segment{}, l.segments[:endIdx+1]...)
		// l.segments[len(l.segments)-2].index 最后的文件，但是未删除
        //  l.segments[len(l.segments)-1].index 带.END的文件
		if len(l.segments) > 1 && l.segments[len(l.segments)-2].index ==
			l.segments[len(l.segments)-1].index {
			// remove the segment prior to the END segment because it shares
			// the same starting index.
			// 重新赋值
			l.segments[len(l.segments)-2] = l.segments[len(l.segments)-1]
			// 左移一个
			l.segments = l.segments[:len(l.segments)-1]
		}
		// Rename the END segment
		orgPath := l.segments[len(l.segments)-1].path
		finalPath := orgPath[:len(orgPath)-len(".END")]
		err := os.Rename(orgPath, finalPath)
		if err != nil {
			return err
		}
		l.segments[len(l.segments)-1].path = finalPath
	}
	l.firstIndex = l.segments[0].index
	// Open the last segment for appending，打开最后一个文件，方便直接写数据
	lseg := l.segments[len(l.segments)-1]
	l.sfile, err = os.OpenFile(lseg.path, os.O_WRONLY, 0666)
	if err != nil {
		return err
	}
	if _, err := l.sfile.Seek(0, 2); err != nil {
		return err
	}
	// Load the last segment entries
    // 加载最后一个文件的数据
	if err := l.loadSegmentEntries(lseg); err != nil {
		return err
	}
    // 更新lastIndex
	l.lastIndex = lseg.index + uint64(len(lseg.epos)) - 1
	return nil
}
```

## 5.tidwall/wal如何写入

### 5.1**日志Write和BatchWrite流程：**
  
1. 首先加锁、检查文件是否冲突和关闭  
2. Write的话，将单条日志条目也写入到内部的wbatch中，最后执行writeBatch(b)  
3. writeBatch中，首先对进来的日志index进行检查，所有的index都是递增的，如果小于当前记录的最后一条日志lastIndex的话，就直接报错  
4. 所有的日志都是进行追加的操作，往最后一个segment文件中追加，遍历b中的条目，根据entry中记录的size拿到entry中的data。最后往segment的ebuf中写入。并同时记录epos信息。  
5. 其中要注意一点，每条日志写入后都要判断当前的segment文件是否已经达到阈值(SegmentSize)了，如果达到的话，则调用cycle()方法，将当前的数据刷到磁盘，然后新建一个新的segment文件，记录segment.Index，并将当前的segmentt放入cache中，继续进行写入。  
6. 日志写入分为两种格式：json和二进制，json的话，会将index和data拼接成一个json串，然后写入到文件中，一个条目一行。  
7. 所有日志写完后，然后释放锁  

### 5.2 源码分析

``` go 
// Write an entry to the log.
func (l *Log) Write(index uint64, data []byte) error {
	l.mu.Lock()
    // 异常检查
	defer l.mu.Unlock()
	if l.corrupt {
		return ErrCorrupt
	} else if l.closed {
		return ErrClosed
	}
	l.wbatch.Clear()
    // 写入到内置的wbatch中
	l.wbatch.Write(index, data)
	return l.writeBatch(&l.wbatch)
}


// WriteBatch writes the entries in the batch to the log in the order that they
// were added to the batch. The batch is cleared upon a successful return.
func (l *Log) WriteBatch(b *Batch) error {
	l.mu.Lock()
	defer l.mu.Unlock()
	if l.corrupt {
		return ErrCorrupt
	} else if l.closed {
		return ErrClosed
	}
	if len(b.entries) == 0 {
		return nil
	}
	return l.writeBatch(b)
}

func (l *Log) writeBatch(b *Batch) error {
	// check that all indexes in batch are sane
	for i := 0; i < len(b.entries); i++ {
		if b.entries[i].index != l.lastIndex+uint64(i+1) {
			return ErrOutOfOrder
		}
	}

	// load the tail segment
	s := l.segments[len(l.segments)-1]
    // 写之前先检查是否满了，满了的话，重新开一个新的segment，往新的segment中写入数据
	if len(s.ebuf) > l.opts.SegmentSize {
		// tail segment has reached capacity. Close it and create a new one.
		if err := l.cycle(); err != nil {
			return err
		}
		s = l.segments[len(l.segments)-1]
	}

	mark := len(s.ebuf)
	datas := b.datas
	for i := 0; i < len(b.entries); i++ {
		// 1. 拿到index对应的data，1和4是相互对应的
		data := datas[:b.entries[i].size]
		
        var epos bpos
		// Write(index,data)一样
		s.ebuf, epos = l.appendEntry(s.ebuf, b.entries[i].index, data)
		s.epos = append(s.epos, epos)
		// 每写入一次，判断是否大于一个块的文件内容了，大于的话，新建一个segment
		if len(s.ebuf) >= l.opts.SegmentSize {
			// segment has reached capacity, cycle now
			if _, err := l.sfile.Write(s.ebuf[mark:]); err != nil {
				return err
			}
			l.lastIndex = b.entries[i].index
			if err := l.cycle(); err != nil {
				return err
			}
			s = l.segments[len(l.segments)-1]
			mark = 0
		}

		// 4. 移动datas
		datas = datas[b.entries[i].size:]
	}

    // 集中写入一个batch后，往文件中写一次
	if len(s.ebuf)-mark > 0 {
		if _, err := l.sfile.Write(s.ebuf[mark:]); err != nil {
			return err
		}
		l.lastIndex = b.entries[len(b.entries)-1].index
	}

    // 判断是否需要刷盘
	if !l.opts.NoSync {
		if err := l.sfile.Sync(); err != nil {
			return err
		}
	}

    // 清空wbatch
	b.Clear()
	return nil
}

```

```go 

// Cycle the old segment for a new segment.
func (l *Log) cycle() error {
	if err := l.sfile.Sync(); err != nil {
		return err
	}
	if err := l.sfile.Close(); err != nil {
		return err
	}
	// cache the previous segment
	l.pushCache(len(l.segments) - 1)
	s := &segment{
		index: l.lastIndex + 1,
		path:  filepath.Join(l.path, segmentName(l.lastIndex+1)),
	}
	var err error
	l.sfile, err = os.Create(s.path)
	if err != nil {
		return err
	}
	l.segments = append(l.segments, s)
	return nil
}

```

```go 
func (l *Log) appendEntry(dst []byte, index uint64, data []byte) (out []byte,
	epos bpos) {
	if l.opts.LogFormat == JSON {
		return appendJSONEntry(dst, index, data)
	}
	return appendBinaryEntry(dst, data)
}
func appendJSONEntry(dst []byte, index uint64, data []byte) (out []byte,
	epos bpos) {
	// {"index":number,"data":string}
	mark := len(dst)
	dst = append(dst, `{"index":"`...)
	dst = strconv.AppendUint(dst, index, 10)
	dst = append(dst, `","data":`...)
	dst = appendJSONData(dst, data)
	dst = append(dst, '}', '\n')
	return dst, bpos{mark, len(dst)}
}

func appendJSONData(dst []byte, s []byte) []byte {
	if utf8.Valid(s) {
		b, _ := json.Marshal(*(*string)(unsafe.Pointer(&s)))
		dst = append(dst, '"', '+')
		return append(dst, b[1:]...)
	}
	dst = append(dst, '"', '$')
	dst = append(dst, base64.URLEncoding.EncodeToString(s)...)
	return append(dst, '"')
}

func appendBinaryEntry(dst []byte, data []byte) (out []byte, epos bpos) {
	// data_size + data
	pos := len(dst)
	dst = appendUvarint(dst, uint64(len(data)))
	dst = append(dst, data...)
	return dst, bpos{pos, len(dst)}
}

func appendUvarint(dst []byte, x uint64) []byte {
	var buf [10]byte
	n := binary.PutUvarint(buf[:], x)
	dst = append(dst, buf[:n]...)
	return dst
}

```


## 6.tidwall/wal如何读取

### 6.1**日志Read流程：**  
  
1. 首先加锁、检查文件是否冲突和关闭、检查index范围是否合法  
2. 接着加载segment  
3. 首先判断该index是否在最后一个segment，如果是就返回  
	1. 其次在cache中寻找，cache中找到后，也就返回  
	2. 走到这一步说明该index所在的segment只有在磁盘中了，需要从磁盘进行加载，所以先找该	index命中哪个segment(segment文件名有序，按照二分查找即可)，找到后从segmentFile	中恢复segment(一方面恢复数据ebuf，另外一方面恢复索引epos)，最后将该segment再放进cache中缓存起来    
4. 找到segment后，可以根据当前的index以及segment记录的index快读定位到位置，然后再从ebuf中读取数据，如果是json的话再进行处理返回，否则直接返回  
5. 最后释放锁 

### 6.2 源码分析

```go
// Read an entry from the log. Returns a byte slice containing the data entry.
func (l *Log) Read(index uint64) (data []byte, err error) {
	l.mu.RLock()
	defer l.mu.RUnlock()
	if l.corrupt {
		return nil, ErrCorrupt
	} else if l.closed {
		return nil, ErrClosed
	}
	// 判断index是否合法，必须在firstIndex~lastIndex之间 
	if index == 0 || index < l.firstIndex || index > l.lastIndex {
		return nil, ErrNotFound
	}
	// 根据index加载segment 
	s, err := l.loadSegment(index)
	if err != nil {
		return nil, err
	}
	// 根据index找到其索引epos，然后直接从ebuf中读取数据 
	epos := s.epos[index-s.index]
	edata := s.ebuf[epos.pos:epos.end]
	if l.opts.LogFormat == JSON {
		return readJSON(edata)
	}
	// binary read
	// 先读取长度
	size, n := binary.Uvarint(edata)
	if n <= 0 {
		return nil, ErrCorrupt
	}
	if uint64(len(edata)-n) < size {
		return nil, ErrCorrupt
	}
	// 然后读取数据 
	if l.opts.NoCopy {
		data = edata[n : uint64(n)+size]
	} else {
		data = make([]byte, size)
		copy(data, edata[n:])
	}
	return data, nil
}


//go:noinline
func readJSON(edata []byte) ([]byte, error) {
	var data []byte
	s := gjson.Get(*(*string)(unsafe.Pointer(&edata)), "data").String()
	if len(s) > 0 && s[0] == '$' {
		var err error
		data, err = base64.URLEncoding.DecodeString(s[1:])
		if err != nil {
			return nil, ErrCorrupt
		}
	} else if len(s) > 0 && s[0] == '+' {
		data = make([]byte, len(s[1:]))
		copy(data, s[1:])
	} else {
		return nil, ErrCorrupt
	}
	return data, nil
}
```


```go 

// loadSegment loads the segment entries into memory, pushes it to the front
// of the lru cache, and returns it.
func (l *Log) loadSegment(index uint64) (*segment, error) {

	// check the last segment first.
    // 先判断是否在最后一个中
	lseg := l.segments[len(l.segments)-1]
	if index >= lseg.index {
		return lseg, nil
	}

	// check the most recent cached segment
    // 再从最近的缓存中寻找
	var rseg *segment
	l.scache.Range(func(_, v interface{}) bool {
		s := v.(*segment)
		if index >= s.index && index < s.index+uint64(len(s.epos)) {
			rseg = s
		}
		return false
	})
	if rseg != nil {
		return rseg, nil
	}
    // 前面两个策略都没找到的话，则从文件中找，首先定位命中的segment是哪个，然后再从segment File中读取数据和重新构建索引
	// find in the segment array
	idx := l.findSegment(index)
	s := l.segments[idx]
	if len(s.epos) == 0 {
		// load the entries from cache
		if err := l.loadSegmentEntries(s); err != nil {
			return nil, err
		}
	}
	// push the segment to the front of the cache
    // 放入cache中
	l.pushCache(idx)
	return s, nil
}


// findSegment performs a bsearch on the segments
// 因为segment的文件名是有序的，所以按照二分查找
func (l *Log) findSegment(index uint64) int {
	i, j := 0, len(l.segments)
	for i < j {
		h := i + (j-i)/2
		if index >= l.segments[h].index {
			i = h + 1
		} else {
			j = h
		}
	}
	return i - 1
}

func (l *Log) loadSegmentEntries(s *segment) error {
	data, err := ioutil.ReadFile(s.path)
	if err != nil {
		return err
	}
	ebuf := data
	var epos []bpos
	var pos int
	// 相当于构建epos索引
	for exidx := s.index; len(data) > 0; exidx++ {
		var n int
		if l.opts.LogFormat == JSON {
			n, err = loadNextJSONEntry(data)
		} else {
			n, err = loadNextBinaryEntry(data)
		}
		if err != nil {
			return err
		}
		data = data[n:]
		epos = append(epos, bpos{pos, pos + n})
		pos += n
	}
	s.ebuf = ebuf
	s.epos = epos
	return nil
}
```

```go
func loadNextJSONEntry(data []byte) (n int, err error) {
	// {"index":number,"data":string}
	idx := bytes.IndexByte(data, '\n')
	if idx == -1 {
		return 0, ErrCorrupt
	}
	line := data[:idx]
	dres := gjson.Get(*(*string)(unsafe.Pointer(&line)), "data")
	if dres.Type != gjson.String {
		return 0, ErrCorrupt
	}
	return idx + 1, nil
}

func loadNextBinaryEntry(data []byte) (n int, err error) {
	// data_size + data
	size, n := binary.Uvarint(data)
	if n <= 0 {
		return 0, ErrCorrupt
	}
	if uint64(len(data)-n) < size {
		return 0, ErrCorrupt
	}
	return n + int(size), nil
}

```

 
## 7.tidwall/wal如何删除

* **TruncateFront:** 清空该index之前的所有数据
* **TruncateBack:** 清空该index之后的所有数据


### 7.1日志TruncateFront流程

**该方法是移除指定的index之前的所有数据，将该index置为firstIndex**

1. 找到该index对应的segment的序号segIdx
2. 加载该index对应的segment
3. 将该index之后的数据写入到一个零时文件(TEMP)中，写入完成后，重命名为s.index.wal.START
4. 将该segment(segIdx)之前的segmentFile文件全部删除掉，完成后，将s.index.wal.START重命名为原先的s.index.wal.START
5. 该方法删除时，需要考虑当删除的文件时最后一个文件时
需要关闭该文件，并重新再打开该文件，读取更新后最新的数据
6. 最后更新segments信息、清除缓存

### 7.2 TruncateFront源码分析

```go 
// segmentName returns a 20-byte textual representation of an index
// for lexical ordering. This is used for the file names of log segments.
func segmentName(index uint64) string {
	return fmt.Sprintf("%020d", index)
}

// TruncateFront truncates the front of the log by removing all entries that
// are before the provided `index`. In other words the entry at
// `index` becomes the first entry in the log.
func (l *Log) TruncateFront(index uint64) error {
	l.mu.Lock()
	defer l.mu.Unlock()
	if l.corrupt {
		return ErrCorrupt
	} else if l.closed {
		return ErrClosed
	}
	return l.truncateFront(index)
}
func (l *Log) truncateFront(index uint64) (err error) {
	if index == 0 || l.lastIndex == 0 ||
		index < l.firstIndex || index > l.lastIndex {
		return ErrOutOfRange
	}
	if index == l.firstIndex {
		// nothing to truncate
		return nil
	}
    // 先找到该index对应的segment的下标segIdx，首先将当前的segment中index之后的数据重新保存，然后后面把该1~segIdx范围内的都删除掉
	segIdx := l.findSegment(index)
	var s *segment
	s, err = l.loadSegment(index)
	if err != nil {
		return err
	}
	epos := s.epos[index-s.index:]
	ebuf := s.ebuf[epos[0].pos:]
	// Create a temp file contains the truncated segment.
	tempName := filepath.Join(l.path, "TEMP")
    // 保存本segment中该index之后的所有数据到temp中
	err = func() error {
		f, err := os.Create(tempName)
		if err != nil {
			return err
		}
		defer f.Close()
		if _, err := f.Write(ebuf); err != nil {
			return err
		}
		if err := f.Sync(); err != nil {
			return err
		}
		return f.Close()
	}()
	// Rename the TEMP file to it's START file name.重命名
	startName := filepath.Join(l.path, segmentName(index)+".START")
	if err = os.Rename(tempName, startName); err != nil {
		return err
	}
	// The log was truncated but still needs some file cleanup. Any errors
	// following this message will not cause an on-disk data ocorruption, but
	// may cause an inconsistency with the current program, so we'll return
	// ErrCorrupt so the the user can attempt a recover by calling Close()
	// followed by Open().
	defer func() {
		if v := recover(); v != nil {
			err = ErrCorrupt
			l.corrupt = true
		}
	}()
	// 删除的是最后一个文件中的数据的时候
	if segIdx == len(l.segments)-1 {
		// Close the tail segment file
		if err = l.sfile.Close(); err != nil {
			return err
		}
	}
	// Delete truncated segment files，删除
	for i := 0; i <= segIdx; i++ {
		if err = os.Remove(l.segments[i].path); err != nil {
			return err
		}
	}
	// Rename the START file to the final truncated segment name.重命名
	newName := filepath.Join(l.path, segmentName(index))
	if err = os.Rename(startName, newName); err != nil {
		return err
	}
	s.path = newName
	s.index = index
	if segIdx == len(l.segments)-1 {
		// Reopen the tail segment file
		if l.sfile, err = os.OpenFile(newName, os.O_WRONLY, 0666); err != nil {
			return err
		}
		var n int64
		if n, err = l.sfile.Seek(0, 2); err != nil {
			return err
		}
		if n != int64(len(ebuf)) {
			err = errors.New("invalid seek")
			return err
		}
		// Load the last segment entries
        // 加载该segment中所有数据
		if err = l.loadSegmentEntries(s); err != nil {
			return err
		}
	}
    // 更新segments
	l.segments = append([]*segment{}, l.segments[segIdx:]...)
	l.firstIndex = index
	l.clearCache()
	return nil
}
```

### 7.3日志TruncateBack流程

**移除指定的index之后的所有日志，将该index变成lastIndex**

1. 首先记录该index对应的segIdx
2. 然后再加载该segment，并将该segment中index之前的数据写入到一个零时文件TEMP中，完成后将该文件重命名为s.index.wal.END。
3. 删除该segment(segIdx)之后的所有segmentFile
4. 再将s.index.wal.END文件重命名为s.index.wal文件
5. 重新打开该文件，并定位到文件尾，方便追加数据
6. 更新segments和lastIndex、然后清空缓存，最后再把该segment从segmentFile中加载出来

### 7.4TruncateBack源码分析

```go 

// TruncateBack truncates the back of the log by removing all entries that
// are after the provided `index`. In other words the entry at `index`
// becomes the last entry in the log.
func (l *Log) TruncateBack(index uint64) error {
	l.mu.Lock()
	defer l.mu.Unlock()
	if l.corrupt {
		return ErrCorrupt
	} else if l.closed {
		return ErrClosed
	}
	return l.truncateBack(index)
}

func (l *Log) truncateBack(index uint64) (err error) {
	if index == 0 || l.lastIndex == 0 ||
		index < l.firstIndex || index > l.lastIndex {
		return ErrOutOfRange
	}
	if index == l.lastIndex {
		// nothing to truncate
		return nil
	}
    // 找到该index对应的segment的下标segIdx，然后将该本segment中的数据保存到临时文件后，移除该segIdx~lastSegmentIdx的文件和数据
	segIdx := l.findSegment(index)
	var s *segment
	s, err = l.loadSegment(index)
	if err != nil {
		return err
	}
    // 该index中对应的数据
	epos := s.epos[:index-s.index+1]
	ebuf := s.ebuf[:epos[len(epos)-1].end]
	// Create a temp file contains the truncated segment.
	tempName := filepath.Join(l.path, "TEMP")
    // 保存数据到TEMP文件中
	err = func() error {
		f, err := os.Create(tempName)
		if err != nil {
			return err
		}
		defer f.Close()
		if _, err := f.Write(ebuf); err != nil {
			return err
		}
		if err := f.Sync(); err != nil {
			return err
		}
		return f.Close()
	}()
	// Rename the TEMP file to it's END file name.
	endName := filepath.Join(l.path, segmentName(s.index)+".END")
	if err = os.Rename(tempName, endName); err != nil {
		return err
	}
	// The log was truncated but still needs some file cleanup. Any errors
	// following this message will not cause an on-disk data ocorruption, but
	// may cause an inconsistency with the current program, so we'll return
	// ErrCorrupt so the the user can attempt a recover by calling Close()
	// followed by Open().
	defer func() {
		if v := recover(); v != nil {
			err = ErrCorrupt
			l.corrupt = true
		}
	}()

	// Close the tail segment file
	if err = l.sfile.Close(); err != nil {
		return err
	}
	// Delete truncated segment files
	// 删除之后的数据
	for i := segIdx; i < len(l.segments); i++ {
		if err = os.Remove(l.segments[i].path); err != nil {
			return err
		}
	}
	// Rename the END file to the final truncated segment name.重命名
	newName := filepath.Join(l.path, segmentName(s.index))
	if err = os.Rename(endName, newName); err != nil {
		return err
	}
	// Reopen the tail segment file
	if l.sfile, err = os.OpenFile(newName, os.O_WRONLY, 0666); err != nil {
		return err
	}
	var n int64
    //移动到文件尾，可以继续write
	n, err = l.sfile.Seek(0, 2)
	if err != nil {
		return err
	}
	if n != int64(len(ebuf)) {
		err = errors.New("invalid seek")
		return err
	}
	s.path = newName
	l.segments = append([]*segment{}, l.segments[:segIdx+1]...)
	l.lastIndex = index
	l.clearCache()
    //加载之前的旧数据
	if err = l.loadSegmentEntries(s); err != nil {
		return err
	}
	return nil
}
```

## 8.参考资料

* [tidwall/wal库github地址](https://github.com/tidwall/wal.git )
* [tidwall/raft-wal库github地址](https://github.com/tidwall/raft-wal.git)
