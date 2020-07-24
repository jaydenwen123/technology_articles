# redis 常用命令总结

## 1.通用名伶

### 1.1 查询key总数

```shell
dbsize
```

### 1.2 查询所有key

```shell
keys *
```

### 1.3 判断key是否存在

```shell
exists key
```


### 1.4 给key设置过期时间

```shell
# 给hello设置3秒后过期
expire hello 3
```

### 1.5 查看key的过期剩余时间

```shell
ttl hello
```


### 0.6 取消key的过期时间设置


```shell
presist hello
```


## 2. string

### 2.1 新增

```shell
set	hello world
```

### 2.2 删除

```shell
del hello
```

### 2.3 修改

```shell
set hello world2

```

### 2.4 查询

```shell
get hello

```

### 2.5 自增、自减

```shell

1.incr 
2.decr
3.incrby
4.decrby

incr hello

incrby hello 3

desc hello

descby hello 4

```

### 2.6 setnx setex

```shell
setnx key world
```


### 2.7 批量操作

```shell
mset hello world hello2 world2

mget hello hello2

```

### 2.8 其他命令1

```shell

# 获取旧值，设置新值
getset

# value追加值
append

# 获取value长度
strlen

```

### 2.9 其他命令2

```shell

incrfloat

getrange

setrange


```

## 3. hash



### 3.1 新增

```shell
hset 

hmset
```

### 3.2 删除

```shell
hdel
```
### 3.3 修改

```shell

```


### 3.4 查询

```shell
hget

hmget
```

### 3.5 是否存在

```shell

hexists

hlen

```

### 3.6 批量操作

```shell
hgetall key

hkeys key

hvals key

hsetnx
```

## 4. list



### 4.1 新增

```shell
1.lpush:左边

2.rpush:右边

rpush key 1 2 3 

3.linsert 

linsert key before 2 4

```


### 4.2 删除

```shell
lpop:左边弹出

rpop:右边弹出

lrem: 删除

lrem key count value

#按照索引范围修剪列表
ltrim key start end
```


### 4.3 修改

```shell

```


### 4.4 查询

```shell
lrange key start end:左闭右闭区间
lrange key 0 -1

#根据索引获取值
lindex key index

#获取长度
llen

```

### 4.5 阻塞api

```shell

blpop

brpop

```


## 5. set




### 5.1 新增

```shell
sadd hobby music art song ball
```


### 5.2 删除

```shell
srem hobby art
```


### 5.3 修改

```shell

```


### 5.4 查询

```shell
scard ：获取集合长度
srandmember :随机获取一个元素
smembers:获取所有元素
sismember:是否存在这个元素

spop:弹出一个元素
```

### 5.5 集合间api

```shell

sinter: 两个集合的并集
sdiff:两个集合的差集
sunion:两个集合的全集

```


## 6. zset


### 6.1 新增

```shell

zadd key score element

zincrby key incrScore element

```


### 6.2 删除

```shell

zrem key element 

```

### 6.3 修改

```shell


```


### 6.4 查询

```shell
zrange:

zcard:长度

```