# io多路复用总结

> 本文主要用来记录自己学习io多路复用时候的一些容易混淆的知识点，其中[这篇文章写的不错](Linux IO模式及 select、poll、epoll详解)

## 一、IO的分类

IO的操作既包括本地IO读写，也包括远程IO（socket）的读写。IO整体上可以划分为两大阶段。

**1. 内核态准备数据阶段**  ：本阶段，主要指在用户发起io请求时，内核态暂时数据还未准备好，此时内核需要等待数据准备就绪。  
**2. 内核态项用户态拷贝数据阶段** ：本阶段指在内核态数据准备就绪后，将内核态的数据拷贝到用户态，应用程序才能使用该部分数据    

下面依次介绍IO的几种分类：

### 1. **阻塞IO** blocking IO

**阻塞IO:**指用户发起io请求时，在上文介绍的第一阶段(内核准备数据)和第二阶段(数据从内核拷贝到用户程序内存中)都需要阻塞等待，因此称为阻塞io。

### 2. **非阻塞IO** no blocking io(NIO)

**非阻塞IO:**指用户发起IO请求时，如果内核态数据未准备就绪，则内核立即返回错误，不会阻塞等待，然后程序不断的轮询，直到内核数据准备就绪后，返回准备就绪标识，此后，数据从内核态拷贝到用户态的过程中，应用程序仍然会阻塞，直到拷贝完成或者中断。非阻塞IO，仅仅指第一阶段是非阻塞的，第二阶段仍然阻塞

### 3. **IO多路复用** io multiplexing

![io多路复用](https://segmentfault.com/img/bVm1c5)

**IO多路复用:IO多路复用和上述前两种io模式的区别在于：IO多路复用主要用来解决应用程序处理多个IO，主要的IO多路复用有select、poll、epoll。后文将详细介绍select、poll和epoll之间的关系和区别。**其IO多路复用也是数据同步非阻塞IO的范畴，只不过它解决的问题是应用程序同时处理多个IO而已

----

```
I/O 多路复用的特点是通过一种机制一个进程能同时等待多个文件描述符，而这些文件描述符
（套接字描述符）其中的任意一个进入读就绪状态，select()函数就可以返回。


这个图和blocking IO的图其实并没有太大的不同，事实上，还更差一些。因为这里需要使用两个system call (select 和 recvfrom)，而blocking IO只调用了一个system call (recvfrom)。但是，用select的优势在于它可以同时处理多个connection。

所以，如果处理的连接数不是很高的话，使用select/epoll的web server不一定比使用multi-threading + blocking IO的web server性能更好，可能延迟还更大。select/epoll的优势并不是对于单个连接能处理得更快，而是在于能处理更多的连接。）

在IO multiplexing Model中，实际中，对于每一个socket，一般都设置成为non-blocking，但是，如上图所示，整个用户的process其实是一直被block的。只不过process是被select这个函数block，而不是被socket IO给block。

作者：人云思云
链接：https://segmentfault.com/a/1190000003063859
来源：SegmentFault 思否
著作权归作者所有。商业转载请联系作者获得授权，非商业转载请注明出处。


```


作者：人云思云
链接：https://segmentfault.com/a/1190000003063859
来源：SegmentFault 思否
著作权归作者所有。商业转载请联系作者获得授权，非商业转载请注明出处。





### 4. **信号驱动IO** signal driving io

**信号驱动IO:**
> 首先注册处理函数到 SIGIO 信号上，在等待数据到来过程结束后，系统触发 SIGIO 信号，之后可以在信号处理函数中执行读数据操作，再唤醒 Main Thread 或直接唤醒 Main Thread 让它去完成数据读取。整个过程没有一处是阻塞的。  
> 看上去很好，但实际几乎没什么人使用，为什么呢？这篇文章给出了一些原因，大致上是说在 TCP 下，连接断开，连接可读，连接可写等等都会产生 Signal，并且在 Signal 上没有提供很好的方法去区分这些 Signal 到底为什么被触发。所以现在还在使用 Signal Driven IO 的基本是 UDP 的


### 5. **异步IO** asyncronized io(AIO)

**异步IO:**异步io指，用户发起io的请求后，然后内核立即返回，此后内核等待数据就绪、然后由内核将内核态准备就绪的数据拷贝到用户态，最后发送signal通知应用程序，阶段1和阶段2都由内核来完成，是真正意义上的异步



## 二、IO几组容易混淆的概念

### 阻塞和非阻塞

从本质来看，阻塞IO属于阻塞，只有其他属于非阻塞，因为第一阶段或者第二阶段都有阻塞

**阻塞和非阻塞主要针对的是内核数据未就绪时的处理策略**


### 同步和异步

从本质来看，阻塞IO、非阻塞IO、IO多路复用、事件驱动IO都属于同步IO，只有异步IO才属于异步IO


### 多线程vs多路复用
> **如果处理的连接数不是很高的话，使用select/epoll的server不一定比使用multi-threading + blocking IO的server性能更好，可能延迟还更大。select/epoll的优势并不是对于单个连接能处理得更快，而是在于能处理更多的连接**





## 三、IO多路复用

目前linux下的多路复用主要有select、poll、epoll，select<poll<epoll。

### select

select函数签名定义如下：

``` c
#include <sys/select.h>

#include <sys/time.h>

int select(int maxfdp1, fd_set *readset, fd_set *writeset, fd_set *exceptset, const struct timeval *timeout);

Returns: positive count of ready descriptors, 0 on timeout, –1 on error
```

> 结构体struct fd\_set是fd\_set是一个位数组，其大小限制为\_\_FD\_SETSIZE（1024），位数组的每一位代表其对应的文件描述符。  
>     参数int maxfdp是所有文件描述符的最大值加1，决定了要扫描的fd_set的范围；  
>     参数fd_set \*readfds、fd_set \*writefds、fd_set \*errorfds包含了一组需要监视其读/写/异常变化的文件描述符；  
>     返回值如果为负，则说明select函数发生了异常；如果为正，则表示某些文件可读写或者异常；为0，则表示超时后，没有可读写或者异常的文件。  
>     参数fd_set \*readfds、fd_set \*writefds、fd_set *errorfds在函数返回后分别记录了那些可读、可写、发生异常的文件描述符。  


**select的缺点**
select的几大缺点：

（1）每次调用select，都需要把fd集合从用户态拷贝到内核态，这个开销在fd很多时会很大

（2）同时每次调用select都需要在内核遍历传递进来的所有fd，这个开销在fd很多时也很大

（3）select支持的文件描述符数量太小了，默认是1024


### poll

![图片地址](http://www.masterraghu.com/subjects/np/introduction/unix_network_programming_v1.3/files/06fig23.gif)

poll 函数的签名如下：

``` c
#include <poll.h>

int poll (struct pollfd *fdarray, unsigned long nfds, int timeout);

Returns: count of ready descriptors, 0 on timeout, –1 on error


struct pollfd {
  int     fd;       /* descriptor to check */
  short   events;   /* events of interest on fd */
  short   revents;  /* events that occurred on fd */
};
```

**分析：**
**1.poll的方式和select相比，poll没有文件描述符的上限，但是当监听的文件描述符过多时，性能会线性下降**

**2.poll和select的相同点在于，他们都需要不断的遍历监听的文件描述符，然后判断是否数据已就绪然后进行处理**

### epoll


``` c
int epoll_create(int size)；//创建一个epoll的句柄，size用来告诉内核这个监听的数目一共有多大
int epoll_ctl(int epfd, int op, int fd, struct epoll_event *event)；
int epoll_wait(int epfd, struct epoll_event * events, int maxevents, int timeout);


struct epoll_event {
  __uint32_t events;  /* Epoll events */
  epoll_data_t data;  /* User data variable */
};

//events可以是以下几个宏的集合：
EPOLLIN ：表示对应的文件描述符可以读（包括对端SOCKET正常关闭）；
EPOLLOUT：表示对应的文件描述符可以写；
EPOLLPRI：表示对应的文件描述符有紧急的数据可读（这里应该表示有带外数据到来）；
EPOLLERR：表示对应的文件描述符发生错误；
EPOLLHUP：表示对应的文件描述符被挂断；
EPOLLET： 将EPOLL设为边缘触发(Edge Triggered)模式，这是相对于水平触发(Level Triggered)来说的。
EPOLLONESHOT：只监听一次事件，当监听完这次事件之后，如果还需要继续监听这个socket的话，需要再次把这个socket加入到EPOLL队列里

```
epoll方法有三步组成：  
    1) 调用int epoll\_create(int size)函数，返回一个epoll句柄epoll\_fd，参数size表述总共打算监控多少个句柄，这个不同于select函数的第一个参数；  
    2) 调用int epoll\_ctl(int epfd, int op, int fd, struct epoll\_event *event)来注册/删除想要监控的文件句柄以及该文件句柄的感兴趣的事件；参数epfd是第一步创建的epoll句柄，参数op可取值为EPOLL\_CTL\_ADD（添加新的句柄）、EPOLL\_CTL\_MOD（修改已注册句柄的被监测事件）、EPOLL\_CTL\_DEL（删除某个句柄），参数fd是要监听的fd，参数event是针对该句柄需要监听的事件。  
    3) 调用 int epoll\_wait(int epfd, struct epoll\_event * events, int maxevents, int timeout);来等待事件的参数，这个函数类似与select函数调用的效果，参数events中保存了被监听句柄的事件情况。  


## 四、select、poll、epoll的区别

### 1.处理并发数

在处理并发数方面，select默认最大为1024个连接，poll没有上限(采用链表)，epoll也没有上限，可以处理百万连接（受机器内存影响，机器内存越大，处理连接越多）

### 2.处理机制

select和poll的处理机制为遍历监听的文件描述符列表，当文件描述符列表越大、空闲连接越多时，性能越低，而且select和poll在每次阻塞时都会将监听的文件描述符列表先从用户态拷贝到内核态。当有描述符准备就绪返回时，又将文件描述符列表从内核态拷贝到用户态，当监听的列表越大时，频繁的拷贝性能较低。

而epoll则是在epoll\_ctl注册、删除想要监控的文件描述符时再内核中建立监听，每个fd只会拷贝一次，效率较高。此外，epoll通过回调的方式处理事件，当空闲连接越多，活跃链接少时性能不会下降


epoll的解决方案不像select或poll一样每次都把current轮流加入fd对应的设备等待队列中，而只在epoll\_ctl时把current挂一遍（这一遍必不可少）并为每个fd指定一个回调函数，当设备就绪，唤醒等待队列上的等待者时，就会调用这个回调函数，而这个回调函数会把就绪的fd加入一个就绪链表）。epoll\_wait的工作实际上就是在这个就绪链表中查看有没有就绪的fd（利用schedule\_timeout()实现睡一会，判断一会的效果，和select实现中的第7步是类似的）。

### 3.监听结果返回效率

select和poll每次都需要从内核态拷贝到用户态，而epoll则是通过mmap在内核态和用户态共享一块内存，不需要频繁拷贝，因此效率较高

## 五、epoll原理

epoll有两种工作模式

**1.ET模式**
ET：edge triggle，边缘出发，主要指，当有fd准备就绪时，如果用户不对该fd做任何操作，后续内核就不会再次通知

**2.LT模式**
LT：level triggle，水平出发，当fd数据准备就绪时，如果用户本次不会该fd做任何操作，后续内核还是会进行通知fd已准备就绪


**ET模式在很大程度上减少了epoll事件被重复触发的次数，因此效率要比LT模式高。epoll工作在ET模式的时候，必须使用非阻塞套接口，以避免由于一个文件句柄的阻塞读/阻塞写操作把处理多个文件描述符的任务饿死**


## 六、参考资料

1. [IO模式和IO多路复用](https://juejin.im/post/5bf7b89e518825369c564059)
2. [Linux IO模式及 select、poll、epoll详解](https://segmentfault.com/a/1190000003063859)
3. [Chapter 6. I/O Multiplexing: The select and poll Functions](http://www.masterraghu.com/subjects/np/introduction/unix_network_programming_v1.3/ch06.html)

