#  golang test测试总结  

## golang test分类

### 1.单元测试test

>  **下面以斐波拉切数列为例，进行单元测试实例**

``` go
fib.go 

func Fib(n int) int {
	if n <= 2 {
		return n
	}
	return Fib(n-1) + Fib(n-2)
}

func Fib2(n int) int {
	if n <= 2 {
		return n
	}
	//f(n)=f(n-1)+f(n-2)
	first, second := 1, 2
	var  tmp  int
	for i := 3; i <= n; i++ {
		tmp=first
		first = second
		second = tmp + second
	}
	return second
}



```

``` go
fib_test.go

package fib

import "testing"

func Test_fib(t *testing.T) {
	// 
	if !flag.Parsed() {
		flag.Parse()
	}
	t.Logf("the flag args:%v",flag.Args())
	
	type args struct {
		n int
	}
	tests := []struct {
		name string
		args args
		want int
	}{
		{
			name: "n=1",
			args: args{
				n: 1,
			},
			want: 1,
		},
		{
			name: "n=5",
			args: args{
				n: 5,
				//1,1,2,3,5
			},
			want: 8,
		},
		{
			name: "n=8",
			args: args{
				n: 8,
			},
			want: 34,
		},{
			name: "n=12",
			args: args{
				n: 12,
			},
			want: 233,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := Fib(tt.args.n); got != tt.want {
				t.Errorf("fib() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestFib2(t *testing.T) {
	type args struct {
		n int
	}
	tests := []struct {
		name string
		args args
		want int
	}{
		{
			name: "n=1",
			args: args{
				n: 1,
			},
			want: 1,
		},
		{
			name: "n=5",
			args: args{
				n: 5,
				//1,1,2,3,5
			},
			want: 8,
		},
		{
			name: "n=8",
			args: args{
				n: 8,
			},
			want: 34,
		},{
			name: "n=12",
			args: args{
				n: 12,
			},
			want: 233,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := Fib2(tt.args.n); got != tt.want {
				t.Errorf("Fib2() = %v, want %v", got, tt.want)
			}
		})
	}
}

```

``` shell
 执行：go test -c && ./fib_test.test -test.v 查看测试程序的详细日志输出
=== RUN   Test_fib
=== RUN   Test_fib/n=1
=== RUN   Test_fib/n=5
=== RUN   Test_fib/n=8
=== RUN   Test_fib/n=12
--- PASS: Test_fib (0.00s)
    --- PASS: Test_fib/n=1 (0.00s)
    --- PASS: Test_fib/n=5 (0.00s)
    --- PASS: Test_fib/n=8 (0.00s)
    --- PASS: Test_fib/n=12 (0.00s)
=== RUN   TestFib2
=== RUN   TestFib2/n=1
=== RUN   TestFib2/n=5
=== RUN   TestFib2/n=8
=== RUN   TestFib2/n=12
--- PASS: TestFib2 (0.00s)
    --- PASS: TestFib2/n=1 (0.00s)
    --- PASS: TestFib2/n=5 (0.00s)
    --- PASS: TestFib2/n=8 (0.00s)
    --- PASS: TestFib2/n=12 (0.00s)
PASS
ok      github.com/jaydenwen123/technolgy_examples/go_test      0.006s


```

### 2.基准测试bench

```shell
执行命令
go test -v -bench . -benchmem -count 2 -cpuprofile cpu.out -memprofile mem.out   -cpu 1,2,4,8

```

```go
基准测试结果：
--- PASS: ExampleFib2 (0.00s)
goos: darwin
goarch: amd64
pkg: github.com/jaydenwen123/technolgy_examples/go_test
BenchmarkFib               52558             23427 ns/op               0 B/op          0 allocs/op
BenchmarkFib               51962             23253 ns/op               0 B/op          0 allocs/op
BenchmarkFib-2             52708             22354 ns/op               0 B/op          0 allocs/op
BenchmarkFib-2             53496             22445 ns/op               0 B/op          0 allocs/op
BenchmarkFib-4             52777             22772 ns/op               0 B/op          0 allocs/op
BenchmarkFib-4             52197             22730 ns/op               0 B/op          0 allocs/op
BenchmarkFib-8             51817             22073 ns/op               1 B/op          0 allocs/op
BenchmarkFib-8             54055             21813 ns/op               0 B/op          0 allocs/op
BenchmarkFib2             130837              8865 ns/op           33033 B/op         34 allocs/op
BenchmarkFib2             137072              8807 ns/op           33033 B/op         34 allocs/op
BenchmarkFib2-2           150097              7957 ns/op           33036 B/op         34 allocs/op
BenchmarkFib2-2           150927              7965 ns/op           33036 B/op         34 allocs/op
BenchmarkFib2-4           156238              7486 ns/op           33041 B/op         34 allocs/op
BenchmarkFib2-4           157786              7419 ns/op           33041 B/op         34 allocs/op
BenchmarkFib2-8           163936              7309 ns/op           33048 B/op         34 allocs/op
BenchmarkFib2-8           165546              7410 ns/op           33048 B/op         34 allocs/op
PASS
ok      github.com/jaydenwen123/technolgy_examples/go_test      21.710s

```

### 3.例子测试example

```go

func ExampleFib() {
	fmt.Println(Fib(2))
	//Output: 2
}

func ExampleFib2() {
	fmt.Println("Fib2:", Fib2(10))
	//	Output: Fib2: 89
}

```

```shell
执行命令：
go test -v -run ^Example
```

``` go
输出结果：(正确)
=== RUN   ExampleFib
--- PASS: ExampleFib (0.00s)
=== RUN   ExampleFib2
--- PASS: ExampleFib2 (0.00s)
PASS
ok      github.com/jaydenwen123/technolgy_examples/go_test      0.004s

输出结果：(错误)
=== RUN   ExampleFib
--- PASS: ExampleFib (0.00s)
=== RUN   ExampleFib2
--- FAIL: ExampleFib2 (0.00s)
got:
Fib2: 89
want:
Fib2: 81
FAIL
exit status 1
FAIL    github.com/jaydenwen123/technolgy_examples/go_test      0.005s

```

### 4.测试main函数

## golang test两种模式
```
以下内容摘自官方描述：
Go test runs in two different modes:

The first, called local directory mode, occurs when go test is
invoked with no package arguments (for example, 'go test' or 'go
test -v'). In this mode, go test compiles the package sources and
tests found in the current directory and then runs the resulting
test binary. In this mode, caching (discussed below) is disabled.
After the package test finishes, go test prints a summary line
showing the test status ('ok' or 'FAIL'), package name, and elapsed
time.

The second, called package list mode, occurs when go test is invoked
with explicit package arguments (for example 'go test math', 'go
test ./...', and even 'go test .'). In this mode, go test compiles
and tests each of the packages listed on the command line. If a
package test passes, go test prints only the final 'ok' summary
line. If a package test fails, go test prints the full test output.
If invoked with the -bench or -v flag, go test prints the full
output even for passing package tests, in order to display the
requested benchmark results or verbose logging. After the package
tests for all of the listed packages finish, and their output is
printed, go test prints a final 'FAIL' status if any package test
has failed.

The rule for a match in the cache is that the run involves the same
test binary and the flags on the command line come entirely from a
restricted set of 'cacheable' test flags, defined as -cpu, -list,
-parallel, -run, -short, and -v. If a run of go test has any test
or non-test flags outside this set, the result is not cached. To
disable test caching, use any test flag or argument other than the
cacheable flags. The idiomatic way to disable test caching explicitly
is to use -count=1. Tests that open files within the package's source
root (usually $GOPATH) or that consult environment variables only
match future runs in which the files and environment variables are unchanged.
A cached test result is treated as executing in no time at all,
so a successful package test result will be cached and reused
regardless of -timeout setting.

```

**1. 本地目录模式**  
> 主要特点是 **禁用缓存**  

**2. 包列表模式**  
> -cpu, -list,-parallel, -run, -short, and -v，等参数时会缓存

## golang test命令详解
```
-args
    Pass the remainder of the command line (everything after -args)
    to the test binary, uninterpreted and unchanged.
    Because this flag consumes the remainder of the command line,
    the package list (if present) must appear before this flag.

-c
	  编译测试的二进制文件，但是不运行，可以使用-o 指定编译后的二进制文件名
    Compile the test binary to pkg.test but do not run it
    (where pkg is the last element of the package's import path).
    The file name can be changed with the -o flag.

-exec xprog
	 指定交叉编译环境，默认不用指定使用go_$GOOS_$GOARCH_exec
    Run the test binary using xprog. The behavior is the same as
    in 'go run'. See 'go help run' for details.
    
    
	By default, 'go run' runs the compiled binary directly: 'a.out arguments...'.
	If the -exec flag is given, 'go run' invokes the binary using xprog:
	        'xprog a.out arguments...'.
	If the -exec flag is not given, GOOS or GOARCH is different from the system
	default, and a program named go_$GOOS_$GOARCH_exec can be found
	on the current search path, 'go run' invokes the binary using that program,
	for example 'go_nacl_386_exec a.out arguments...'. This allows execution of
	cross-compiled programs when a simulator or other execution method is
	available.


-i
	  安装测试依赖的包，但是不运行测试
    Install packages that are dependencies of the test.
    Do not run the test.

-json
	  将测试输出转换为json格式
    Convert test output to JSON suitable for automated processing.
    See 'go doc test2json' for the encoding details.

-o file
	 指定编译的测试二进制程序的文件名
    Compile the test binary to the named file.
    The test still runs (unless -c or -i is specified).
```

## 常用的测试命令
### 1.指定测试二进制程序名编译，并不执行
	go test -c -o $obj
### 	2.执行测试二进制程序,-test.v查看详细输出 -test.run指定执行的测试函数
	./$obj -test.v -test.run xxx
### 	3.执行基准测试
	go test -v -bench . 
### 	4.执行指定次数
	go test -v -bench . -count 2
### 	5.执行指定cpu核数
	go test -v -bench . -cpu 1,2,4
### 	6.基准测试时打印内存占比
	go test -v -bench . -benchmem
### 	7.生成cpu、mem、协程阻塞性能分析文件
	go test -bench . -v -memprofile  mem.out -blockprofile block.out -cpuprofile cpu.out -count 2 -benchmem
### 	8.通过go tool pprof查看
	go tool pprof mem.out 
### 	输入web以浏览器方式查看、输入pdf，导出pdf版本
### 	9.导出代码覆盖率
	go test -v -coverprofile cover.out
###  10.代码覆盖率导出成html
	go tool cover -html=cover.out -o cover.html
	
### 11.使用flag var传递
	
**程序编写**

```go
var flag1 string

var flag2 int

func init() {
	flag.StringVar(&flag1,"var1","hello","enter var1")
	flag.IntVar(&flag2,"var2",3,"enter var2")
}

func TestFlag(t *testing.T){
	t.Logf("flag1:%v",flag1)
	t.Logf("flag2:%v",flag2)
}


```

**通过-h查看帮助**

```shell
./go_test.test -h
false
Usage of ./go_test.test:
 	-var1 string
        enter var1 (default "hello")
  -var2 int
        enter var2 (default 3)
  -hello string
        hello need input (default "123")
  -test.bench regexp
        run only benchmarks matching regexp
  -test.benchmem
        print memory allocations for benchmarks
  -test.benchtime d
        run each benchmark for duration d (default 1s)
  -test.blockprofile file
        write a goroutine blocking profile to file
  -test.blockprofilerate rate
        set blocking profile rate (see runtime.SetBlockProfileRate) (default 1)
  -test.timeout d
        panic test binary after duration d (default 0, timeout disabled)
  -test.trace file
        write an execution trace to file
  -test.v
        verbose: print additional output
 
```

**程序运行传递参数**  

```shell
go test -c && ./go_test.test -test.v -test.run TestFlag -var1 hellowrold -var2 234
false
=== RUN   TestFlag
--- PASS: TestFlag (0.00s)
    flag_test.go:18: flag1:hellowrold
    flag_test.go:19: flag2:234
PASS
```

### 12.使用flag.Args -args参数

```shell

指示go test把-args后面的参数带到测试中去。具体的测试函数会跟据此参数来控制测试流程。

-args后面可以附带多个参数，所有参数都将以字符串形式传入，每个参数做为一个string，并存放到字符串切片中。

// TestArgs 用于演示如何解析-args参数
func TestArgs(t *testing.T) {
	if !flag.Parsed() {
		flag.Parse()
	}

	argList := flag.Args() // flag.Args() 返回 -args 后面的所有参数，以切片表示，每个元素代表一个参数
	t.Log("argList:",argList)
	for _, arg := range argList {
		if arg == "cloud" {
			t.Log("Running in cloud.")
		}else {
			t.Log("Running in other mode.")
		}
	}
}
```

**方式一、编译二进制然后执行**

```shell

go test -c && ./go_test.test -test.v -test.run TestArgs  "12312" "12313"
false
=== RUN   TestArgs
--- PASS: TestArgs (0.00s)
    flag_test.go:30: argList: [12312 12313]
    flag_test.go:35: Running in other mode.
    flag_test.go:35: Running in other mode.
PASS


```


**方式二：直接执行run**

**直接run时，需要通过-args指定参数**

```shell

go test -v -run TestArgs -args 123 12313
false
=== RUN   TestArgs
--- PASS: TestArgs (0.00s)
    flag_test.go:30: argList: [123 12313]
    flag_test.go:35: Running in other mode.
    flag_test.go:35: Running in other mode.
PASS
ok      github.com/jaydenwen123/technolgy_examples/go_test      0.007s


```


## 常用测试选项
``` shell
	关于 flags for test binary ，调用go help testflag，这些是go test过程中经常使用到的参数
	-test.v : 是否输出全部的单元测试用例（不管成功或者失败），默认没有加上，所以只输出失败的单元测试用例。
	-test.run pattern: 只跑哪些单元测试用例
	-test.bench patten: 只跑那些性能测试用例
	-test.benchmem : 是否在性能测试的时候输出内存情况
	-test.benchtime t : 性能测试运行的时间，默认是1s
	-test.cpuprofile cpu.out : 是否输出cpu性能分析文件
	-test.memprofile mem.out : 是否输出内存性能分析文件
	-test.blockprofile block.out : 是否输出内部goroutine阻塞的性能分析文件
	-test.coverprofile  cover.out : 收集代码覆盖率
```
**代码覆盖率样图**
![代码覆盖图片](https://github.com/jaydenwen123/technolgy_examples/raw/master/go_test/cover.jpg)

## golang test第三方包介绍
1. [google测试框架gomock](https://github.com/golang/mock)
2. [第三方断言库testify](https://github.com/stretchr/testify)

## 参考资料
1. [Go test 命令行参数](https://blog.csdn.net/weixin_33906657/article/details/91699657)
2. [go test 命令介绍](https://blog.csdn.net/csapr1987/article/details/44938947)
3. [golang test说明解读](https://blog.csdn.net/weixin_33738578/article/details/85537120)
4. [Golang单元测试与覆盖率](https://blog.csdn.net/m0_37554486/article/details/78917471)
5. [Golang 单元测试和性能测试](https://blog.csdn.net/shenlanzifa/article/details/51451814)
6. [golang 单元测试与性能分析](https://juejin.im/post/5e33fb516fb9a030073b5462)
7. [搞定Go单元测试（二）—— mock框架(gomock)](https://juejin.im/post/5ce9354b5188252a72407ac5)
8. [搞定Go单元测试（三）—— 断言（testify）](https://juejin.im/post/5ce935a1e51d4510aa01147b)
9. [搞定Go单元测试（四）—— 依赖注入框架(wire)](https://juejin.im/post/5ce935dcf265da1ba431c998)
10. [go test 及测试覆盖率【 Go 夜读 】](https://www.bilibili.com/video/BV15b411z74v)
11. [Golang Testing单元测试指南](https://www.cnblogs.com/sunsky303/p/11818480.html)

