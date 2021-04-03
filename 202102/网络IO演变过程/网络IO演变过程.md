# 网络IO演变过程

在互联网中提起网络，我们都会避免不了讨论高并发、百万连接。而此处的百万连接的实现，脱离不了网络IO的选择，因此本文作为一篇个人学习的笔记，特此进行记录一下整个网络IO的发展演变过程。以及目前广泛使用的网络模型。

## 1.网络IO的发展

在本节内容中，我们将一步一步介绍网络IO的演变发展过程。介绍完发展过程后，再对网络IO中几组容易混淆的概念进行对比、分析。

![](./imgs/linux_network.jpeg)

### 1.1网络IO的各个发展阶段

通常，我们在此讨论的网络IO一般都是针对linux操作系统而言。网络IO的发展过程是随着linux的内核演变而变化，因此网络IO大致可以分为如下几个阶段：

**1. 阻塞IO(BIO)**  
**2. 非阻塞IO(NIO)**  
**3. IO多路复用第一版(select/poll)**  
**4. IO多路复用第二版(epoll)**  
**5. 异步IO(AIO)**  

而每一个阶段，都是因为当前的网络有一些缺陷，因此又在不断改进该缺陷。这是**网络IO一直演变过程中的本质**。下面将对上述几个阶段进行介绍，并对每个阶段的网络IO解决了哪些问题、优点、缺点进行剖析。

![](./imgs/网络IO、IO多路复用总结.png)

### 1.2 网络的两个阶段

在网络中，我们通常可以将其广义上划分为以下两个阶段： 

**第一阶段：硬件接口到内核态**   
**第二阶段：内核态到用户态**   

本人理解：我们通常上网，大部分数据都是通过网线传递的。因此对于两台计算机而言，要进行网络通信，其数据都是先从应用程序传递到传输层(TCP/UDP)到达内核态，然后再到网络层、数据链路层、物理层，接着数据传递到硬件网卡，最后通过网络传输介质传递到对端机器的网卡，然后再一步一步数据从网卡传递到内核态，最后再拷贝到用户态。

![](./imgs/kernel_user.png)

### 1.3阻塞IO和非阻塞IO的区别

根据1.2节的内容，我们可以知道，网络中的数据传输从网络传输介质到达目的机器，需要如上两个阶段。此处我们把从**硬件到内核态**这一阶段，是否发生阻塞等待，可以将网络分为**阻塞IO**和**非阻塞IO**。如果用户发起了读写请求，但内核态数据还未准备就绪，该阶段不会阻塞用户操作，内核立马返回，则称为非阻塞IO。如果该阶段一直阻塞用户操作。直到内核态数据准备就绪，才返回。这种方式称为阻塞IO。

因此，区分阻塞IO和非阻塞IO主要看第一阶段是否阻塞用户操作。

### 1.4同步IO和异步IO的区别

从前面我们知道了，数据的传递需要两个阶段，在此处只要任何一个阶段会阻塞用户请求，都将其称为同步IO，两个阶段都不阻塞，则称为异步IO。

在目前所有的操作系统中，linux中的epoll、mac的kqueue都属于同步IO，因为其在第二阶段(数据从内核态到用户态)都会发生拷贝阻塞。
而只有windows中的IOCP才真正属于异步IO，即AIO。

## 2.阻塞IO

在本节，我们将介绍最初的阻塞IO，阻塞IO英文为blocking IO，又称为BIO。根据前面的介绍，阻塞IO主要指的是第一阶段(硬件网卡到内核态)。

### 2.1阻塞IO的概念

阻塞IO，顾名思义当用户发生了系统调用后，如果数据未从网卡到达内核态，内核态数据未准备好，此时会一直阻塞。直到数据就绪，然后从内核态拷贝到用户态再返回。具体过程可以参考2.2的图示。

### 2.2阻塞IO的过程

![](./imgs/blockingIO.png)

### 2.3阻塞IO的缺点

在一般使用阻塞IO时，都需要配置多线程来使用，最常见的模型是**阻塞IO+多线层**，每个连接一个单独的线程进行处理。

**我们知道，一般一个程序可以开辟的线程是优先的，而且开辟线程的开销也是比较大的。也正是这种方式，会导致一个应用程序可以处理的客户端请求受限。面对百万连接的情况，是无法处理。**

既然发现了问题，分析了问题，那就得解决问题。既然阻塞IO有问题，本质是由于其阻塞导致的，因此自然而然引出了下面即将介绍的主角：**非阻塞IO**

## 3.非阻塞IO

非阻塞IO是为了解决前面提到的阻塞IO的缺陷而引出的，下面我们将介绍非阻塞IO的过程。

### 3.1非阻塞IO的概念

非阻塞IO：见名知意，就是在第一阶段(网卡-内核态)数据未到达时不等待，然后直接返回。因此非阻塞IO需要不断的用户发起请求，询问内核数据好了没，好了没。

### 3.2非阻塞IO的过程
![](./imgs/noblockingIO.png)

非阻塞IO是需要系统内核支持的，在创建了连接后，可以调用setsockop设置noblocking

### 3.3非阻塞IO的优点

正如前面提到的，非阻塞IO解决了阻塞IO**每个连接一个线程处理的问题**，所以其最大的优点就是 **一个线程可以处理多个连接**，这也是其非阻塞决定的。

### 3.4非阻塞IO的缺点

但这种模式，也有一个问题，就是需要用户多次发起系统调用。**频繁的系统调用**是比较消耗系统资源的。

因此，既然存在这样的问题，那么自然而然我们就需要解决该问题：**保留非阻塞IO的优点的前提下，减少系统调用**

## 4.IO多路复用第一版

为了解决非阻塞IO存在的频繁的系统调用这个问题，随着内核的发展，出现了IO多路复用模型。那么我们就需要搞懂几个问题：

1. IO多路复用到底复用什么？
2. IO多路复用如何复用？

**IO多路复用：** 很多人都说，IO多路复用是用一个线程来管理多个网络连接，但本人不太认可，因为在非阻塞IO时，就已经可以实现一个线程处理多个网络连接了，这个是由于其非阻塞而决定的。

 **在此处，个人观点，多路复用主要复用的是通过有限次的系统调用来实现管理多个网络连接。最简单来说，我目前有10个连接，我可以通过一次系统调用将这10个连接都丢给内核，让内核告诉我，哪些连接上面数据准备好了，然后我再去读取每个就绪的连接上的数据。因此，IO多路复用，复用的是系统调用。通过有限次系统调用判断海量连接是否数据准备好了**
 
 
 **无论下面的select、poll、epoll，其都是这种思想实现的，不过在实现上，select/poll可以看做是第一版，而epoll是第二版**

### 4.1IO多路复用第一版的概念

**IO多路复用第一版，这个概念是本人想出来的，主要是方便将select/poll和epoll进行区分**

所以此处IO多路复用第一版，主要特指select和poll这两个。

select的api

``` c
// readfds:关心读的fd集合；writefds：关心写的fd集合；excepttfds：异常的fd集合
int select (int n, fd_set *readfds, fd_set *writefds, fd_set *exceptfds, struct timeval *timeout);

```

> select 函数监视的文件描述符分3类，分别是writefds、readfds、和exceptfds。调用后select函数会阻塞，直到有描述副就绪（有数据 可读、可写、或者有except），或者超时（timeout指定等待时间，如果立即返回设为null即可），函数返回。当select函数返回后，可以 通过遍历fdset，来找到就绪的描述符。

> select目前几乎在所有的平台上支持，其良好跨平台支持也是它的一个优点。select的一 个缺点在于单个进程能够监视的文件描述符的数量存在最大限制，在Linux上一般为1024，可以通过修改宏定义甚至重新编译内核的方式提升这一限制，但 是这样也会造成效率的降低。

poll的api

```c
int poll (struct pollfd *fds, unsigned int nfds, int timeout);

struct pollfd {
    int fd; /* file descriptor */
    short events; /* requested events to watch */
    short revents; /* returned events witnessed */
};

```

> pollfd结构包含了要监视的event和发生的event，不再使用select“参数-值”传递的方式。同时，pollfd并没有最大数量限制（但是数量过大后性能也是会下降）。 和select函数一样，poll返回后，需要轮询pollfd来获取就绪的描述符。

> 从上面看，select和poll都需要在返回后，通过遍历文件描述符来获取已经就绪的socket。事实上，同时连接的大量客户端在一时刻可能只有很少的处于就绪状态，因此随着监视的描述符数量的增长，其效率也会线性下降。

**从本质来说：IO多路复用中，select()/poll()/epoll_wait()这几个函数对应第一阶段；read()/recvfrom()对应第二阶段**

### 4.2IO多路复用第一版的过程
![](./imgs/IOmulti.png)

### 4.3IO多路复用第一版的优点

**IO多路复用，主要在于复用，通过select()或者poll()将多个socket fds批量通过系统调用传递给内核，由内核进行循环遍历判断哪些fd上数据就绪了，然后将就绪的readyfds返回给用户。再由用户进行挨个遍历就绪好的fd，读取或者写入数据。**

**所以通过IO多路复用+非阻塞IO，一方面降低了系统调用次数，另一方面可以用极少的线程来处理多个网络连接。**

### 4.4IO多路复用第一版的缺点

虽然第一版IO多路复用解决了之前提到的频繁的系统调用次数，但同时引入了新的问题：**用户需要每次将海量的socket fds集合从用户态传递到内核态，让内核态去检测哪些网络连接数据就绪了**

**但这个地方会出现频繁的将海量fd集合从用户态传递到内核态，再从内核态拷贝到用户态。
所以，这个地方开销也挺大。**

既然还有这个问题，那我们继续开始解决这个问题，因此就引出了第二版的IO多路复用。

**其实思路也挺简单，既然需要拷贝，那就想办法，不拷贝。既然不拷贝，那就在内核开辟一段区域咯**

### 4.5IO多路复用第一版的区别

**select和poll的区别**

1. select能处理的最大连接，默认是1024个，可以通过修改配置来改变，但终究是有限个；而poll理论上可以支持无限个
2. select和poll在管理海量的连接时，会频繁的从用户态拷贝到内核态，比较消耗资源。


## 5.IO多路复用第二版

IO多路复用第二版主要指epoll，epoll的出现也是随着内核版本迭代才诞生的，在网上到处看到，epoll是内核2.6以后开始支持的

**epoll的出现是为了解决前面提到的IO多路复用第一版的问题**


### 5.1IO多路复用第二版的概念

epoll提供的api

```c
//创建epollFd，底层是在内核态分配一段区域，底层数据结构红黑树+双向链表
int epoll_create(int size)；//创建一个epoll的句柄，size用来告诉内核这个监听的数目一共有多大

//往红黑树中增加、删除、更新管理的socket fd
int epoll_ctl(int epfd, int op, int fd, struct epoll_event *event)；

//这个api是用来在第一阶段阻塞，等待就绪的fd。
int epoll_wait(int epfd, struct epoll_event * events, int maxevents, int timeout);
```

```shell
1. int epoll_create(int size);
创建一个epoll的句柄，size用来告诉内核这个监听的数目一共有多大，这个参数不同于select()中的第一个参数，给出最大监听的fd+1的值，参数size并不是限制了epoll所能监听的描述符最大个数，只是对内核初始分配内部数据结构的一个建议。
当创建好epoll句柄后，它就会占用一个fd值，在linux下如果查看/proc/进程id/fd/，是能够看到这个fd的，所以在使用完epoll后，必须调用close()关闭，否则可能导致fd被耗尽。

2. int epoll_ctl(int epfd, int op, int fd, struct epoll_event *event)；
函数是对指定描述符fd执行op操作。
- epfd：是epoll_create()的返回值。
- op：表示op操作，用三个宏来表示：添加EPOLL_CTL_ADD，删除EPOLL_CTL_DEL，修改EPOLL_CTL_MOD。分别添加、删除和修改对fd的监听事件。
- fd：是需要监听的fd（文件描述符）
- epoll_event：是告诉内核需要监听什么事，struct epoll_event结构如下：

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

3. int epoll_wait(int epfd, struct epoll_event * events, int maxevents, int timeout);
等待epfd上的io事件，最多返回maxevents个事件。
参数events用来从内核得到事件的集合，maxevents告之内核这个events有多大，这个maxevents的值不能大于创建epoll_create()时的size，参数timeout是超时时间（毫秒，0会立即返回，-1将不确定，也有说法说是永久阻塞）。该函数返回需要处理的事件数目，如返回0表示已超时。

```

> 二 工作模式
　epoll对文件描述符的操作有两种模式：LT（level trigger）和ET（edge trigger）。LT模式是默认模式，LT模式与ET模式的区别如下：
　　LT模式：当epoll_wait检测到描述符事件发生并将此事件通知应用程序，应用程序可以不立即处理该事件。下次调用epoll_wait时，会再次响应应用程序并通知此事件。
　　ET模式：当epoll_wait检测到描述符事件发生并将此事件通知应用程序，应用程序必须立即处理该事件。如果不处理，下次调用epoll_wait时，不会再次响应应用程序并通知此事件。

> 1. LT模式
LT(level triggered)是缺省的工作方式，并且同时支持block和no-block socket.在这种做法中，内核告诉你一个文件描述符是否就绪了，然后你可以对这个就绪的fd进行IO操作。如果你不作任何操作，内核还是会继续通知你的。

> 2. ET模式
ET(edge-triggered)是高速工作方式，只支持no-block socket。在这种模式下，当描述符从未就绪变为就绪时，内核通过epoll告诉你。然后它会假设你知道文件描述符已经就绪，并且不会再为那个文件描述符发送更多的就绪通知，直到你做了某些操作导致那个文件描述符不再为就绪状态了(比如，你在发送，接收或者接收请求，或者发送接收的数据少于一定量时导致了一个EWOULDBLOCK 错误）。但是请注意，如果一直不对这个fd作IO操作(从而导致它再次变成未就绪)，内核不会发送更多的通知(only once)

ET模式在很大程度上减少了epoll事件被重复触发的次数，因此效率要比LT模式高。epoll工作在ET模式的时候，必须使用非阻塞套接口，以避免由于一个文件句柄的阻塞读/阻塞写操作把处理多个文件描述符的任务饿死。

### 5.2IO多路复用第二版的过程
![](./imgs/IOmulti.png)

当epoll_wait()调用后会阻塞，然后完了当返回时，会返回了哪些fd的数据就绪了，用户只需要遍历就绪的fd进行读写即可。

### 5.3IO多路复用第二版的优点

**IO多路复用第二版epoll的优点在于：**

一开始就在内核态分配了一段空间，来存放管理的fd,所以在每次连接建立后，交给epoll管理时，需要将其添加到原先分配的空间中，后面再管理时就不需要频繁的从用户态拷贝管理的fd集合。通通过这种方式大大的提升了性能。

所以现在的IO多路复用主要指epoll

### 5.4IO多路复用第二版的缺点
**个人猜想：**如何降低占用的空间

## 6.异步IO

#### 6.1异步IO的过程

![](./imgs/asyncIO.png)

前面介绍的所有网络IO都是同步IO，因为当数据在内核态就绪时，在内核态拷贝用用户态的过程中，仍然会有短暂时间的阻塞等待。而异步IO指：**内核态拷贝数据到用户态这种方式也是交给系统线程来实现，不由用户线程完成**，目前只有windows系统的IOCP是属于异步IO。




## 7.网络IO各种模型

### 7.1 reactor模型

目前reactor模型有以下几种实现方案：

**1. 单reactor单线程模型**  
**2. 单reactor多线程模型**  
**3. multi-reactor多线程模型**  
**4. multi-reactor多进程模型** 

> 下文网络模型的图，均摘自[这篇文章](https://zhuanlan.zhihu.com/p/95662364)

#### 7.1.1 单reactor单线程模型
此种模型，通常是只有一个epoll对象，所有的**接收客户端连接**、**客户端读取**、**客户端写入**操作都包含在一个线程内。该种模型也有一些中间件在用，比如redis

![](./imgs/single_reactor_single_thread.jpg)

> 但在目前的单线程Reactor模式中，不仅I/O操作在该Reactor线程上，连非I/O的业务操作也在该线程上进行处理了，这可能会大大延迟I/O请求的响应。所以我们应该将非I/O的业务逻辑操作从Reactor线程上卸载，以此来加速Reactor线程对I/O请求的响应。


#### 7.1.2 单reactor多线程模型 

该模型主要是通过将，前面的模型进行改造，将读写的业务逻辑交给具体的线程池来实现，这样可以显示reactor线程对IO的响应，以此提升系统性能
![](./imgs/single_reactor_thread_pool.jpg)

> 在工作者线程池模式中，虽然非I/O操作交给了线程池来处理，但是所有的I/O操作依然由Reactor单线程执行，在高负载、高并发或大数据量的应用场景，依然较容易成为瓶颈。所以，对于Reactor的优化，又产生出下面的多线程模式。



#### 7.1.3 multi-reactor多线程模型

在这种模型中，主要分为两个部分：mainReactor、subReactors。
mainReactor主要负责接收客户端的连接，然后将建立的客户端连接通过负载均衡的方式分发给subReactors，

subReactors来负责具体的每个连接的读写

对于非IO的操作，依然交给工作线程池去做，对逻辑进行解耦


![](./imgs/multi_reactor_multi_thread.jpg)

> mainReactor对应Netty中配置的BossGroup线程组，主要负责接受客户端连接的建立。一般只暴露一个服务端口，BossGroup线程组一般一个线程工作即可
subReactor对应Netty中配置的WorkerGroup线程组，BossGroup线程组接受并建立完客户端的连接后，将网络socket转交给WorkerGroup线程组，然后在WorkerGroup线程组内选择一个线程，进行I/O的处理。WorkerGroup线程组主要处理I/O，一般设置2*CPU核数个线程

### 7.2 proactor模型

proactor主要是通过对异步IO的封装的一种模型，它需要底层操作系统的支持，目前只有windows 的IOCP支持的比较好。详细的介绍可以参考[这篇文章](https://zhuanlan.zhihu.com/p/95662364)

### 7.3 主流的中间件所采用的网络模型

![](./imgs/network_middle_ware.jpeg)

### 7.4 主流网络框架

* netty
* gnet
* libevent


## 8.参考资料  
1. [IO模式和IO多路复用](https://juejin.im/post/5bf7b89e518825369c564059)
2. [Linux IO模式及 select、poll、epoll详解](https://segmentfault.com/a/1190000003063859)
3. [Chapter 6. I/O Multiplexing: The select and poll Functions](http://www.masterraghu.com/subjects/np/introduction/unix_network_programming_v1.3/ch06.html)
4. [高性能IO模型分析-Reactor模式和Proactor模式（二）](https://zhuanlan.zhihu.com/p/95662364)
