---
title: "系统调用、进程与 IO"
date: 2020-08-08T16:03:20+08:00
lastmod: 2020-08-08T16:03:20+08:00
draft: false
categories: ["go"]
tags: ["go", "java"]
typora-root-url: ../../static
---

对于这么互联网从业者来说，`IO` 特别是 `网络 IO`从来都是大问题，尤其是在当前大行其道的 `微服务` 体系下，大厂可能有上万个微服务，某个接口可能有数十个 `RPC 调用`，还有诸如各种中间件，如各种`proxy` ，虽然可能就`几 ms` 级别的开销，但最终都是性能瓶颈所在。

在最常用的 `Linux` 下，对于 `IO` 甚至各大开源软件的技术特点的理解，我觉得可以先从大局开始了解，也就是，从 `Linux Kernel` 开始。

## 系统调用与库函数

系统调用与库函数的关系，可以简单理解如下：所谓系统调用，其实是内核向用户态暴露的接口，而库函数是 `c` 下对这些系统调用的封装。

比如 `fwrite` 内部是系统调用 `write`，我们可以分别查看 `man 2 write`、`man 3 fwrite` 查看，其中 `man 2` 表示 `System Calls Manual`，`man 3` 表示 `Library Functions Manual`。

因为用户进程下，是无法直接操纵计算机的硬件资源等，如磁盘、网卡等待，这些都属于内核管理的范畴，也即所谓的 `保护模式`。所以当用户态进程需要使用操作系统底层功能时，需要使用库函数封装下的系统调用取告诉内核自己需要干什么。而每个系统调用，都会产生一次 `用户态 - 内核态` 的切换，也即所谓的 `CPU 上下文切换`。在某次系统调用结束后，`CPU` 会把调用结果返回给 `用户态`，这样又多了一次  `内核态 - 用户态` 的切换。

系统调用有为广义和狭义的区分，如上文提到的 `write` 是广义的系统调用范畴，也即我们平时说的系统调，`Standard C Library (libc, -lc)`。实际上其也是一个封装函数，真正调用的是 `sys_write` 函数，也即所谓狭义的系统调用。换言之，内核提供的服务称之为真正的底层系统调用，我们常说的系统调用其实是 `glibc` 对齐的封装，为什么要再次封装呢，因为这些内核服务太底层了，直接用太简单粗暴，封装一层后可以屏蔽更多细节。所以能否调用某个内核服务，还需要看当前 `glibc` 是否支持，比如 `epoll`：

```
  The epoll API was introduced in Linux kernel 2.5.44.  Support was
       added to glibc in version 2.3.2.
```

那么系统调用到底是怎么工作的呢？其实其本质是以 `软中断` 的形式实现的，当用户态进程发起一个系统调用后， `软中断` 发生，`CPU` 进入内核态，然后根据具体的系统调用跳转到内核指定的服务，比如写文件、读 `socket` 等待，也即会调用真正的内核函数，如上面提到的 `sys_write`，最后将结果交由 `CPU` 返回给调用方的用户进程。

## 进程与信号控制

### 进程

我们知道，`进程` 是操作系统中程序执行最小单位，其中几个专用进程如下:

* `0 号进程`：内核调度进程，也即交换进程（`swapper`），属于系统进程。在操作系统启动 `自举`，然后调用 `kernel_thread` 生成一个内核线程去执行 `init` 函数，执行一些初始化操作；

* `1 号进程`：`init 进程`。在内核自举过程中，`0 号进程` 派生的内核线程 `init` 完成后调用 `execve` ，载入用户空间的可执行程序 `/sbin/init`，拥有了自己的属性资源，变成了 `1 号进程`，成为一个普通的用户进程。注意，`init 进程` 不是内核的系统进程，但是它以 `root` 权限运行，也是所有孤儿进程的父进程。

在 `Linux` 系统下，整个进程是从 `0-1-...` 的进程树结构存在的。`fork` 可用于创建子进程，子进程拥有父进程的数据空间、堆和栈的副本（非共享，注意与线程的区别），与父进程共享正文段。这里开销较大，后来优化成了 `Copy On Write， COWW` 机制，也即所谓的写时复制。在 `COW` 机制下，父进程与子进程共享数据空间、堆、栈等，内核负责将其访问权限改为`只读`，当父、子进程需要修改这些区域的内容时，再 `copy` 一份副本。

子进程可以通过 `getppid` 获取父进程的进程 `id`，并会继承父进程众多熟悉，如文件描述符、所属组、资源限制、信号处理、环境等等。`fork` 使用范式如下：

```c
pid_t pid;
if ((pid = fork()) < 0) {
	// fork 出错
} else if (pid == 0) {
	// 子进程处理逻辑，与父进程相对独立，如可同时修改变量
}	else {
	// 父进程处理逻辑
}
// 下面是正文段，父、子进程共享，但相互独立，也即这段程序都会执行
```

### 信号控制

上一小节，我们大致讲解了下 `linux` 进程的一些知识，这里有些问题需要考量，比如子进程退出了，父进程需不需要知道呢？或者，父进程先退出，那子进程又该如何处理呢？

* 子进程在 `exit`、`return` 等调用后退出时，这个异步事件可能会发生在父进程运行的任何时间内，内核会发送一个 `SIGCHILD` 信号，该信号默认操作是忽略，父进程也可以捕获该信号，使用了 `wait` 或 `waitpid` 获取子进程状态，俩者区别是 `wait` 会阻塞父进程，`waitpid` 可配置成不阻塞模式，并做相关处理，如资源回收
* 如果使用了 `wait` 或 `waitpid`


处理子进程退出的方式一般是注册一个信号处理函数，捕捉信号 SIGCHILD 信号，然后再在信号处理函数里调用 waitpid 函数来完成子进程资源的回收。SIGCHLD 是子进程退出或者中断时由内核向父进程发出的信号，默认这个信号是忽略的。所以，如果想在子进程退出时能回收它，需要像下面一样，注册一个 SIGCHOLD 函数。

## IO 模型

下面主要讨论的是 `network IO`，也即网络 `IO`，一个常见的网络编程范式如下：

* `signal(SIGCHLD, SIG_IGN);`

多进程并发服务器下，`fork` 的子进程接收后，一般需要主进程 `wait`、`waitpid` 等清理资源，并发服务器常常 `fork很多子进程，子进程终结之后需要服务器进程去wait清理资源。如果将此信号的处理方式设为忽略，可让内核把僵尸子进程转交给init进程去处理，省去了大量僵尸进程占用系统资源。(Linux Only)

对于某些进程，特别是服务器进程往往在请求到来时生成子进程处理请求。如果父进程不等待子进程结束，子进程将成为僵尸进程（zombie）从而占用系统资源。如果父进程等待子进程结束，将增加父进程的负担，影响服务器进程的并发性能。在Linux下可以简单地将 SIGCHLD信号的操作设为SIG_IGN。


signal(SIGPIPE, SIG_IGN);

TCP是全双工的信道, 可以看作两条单工信道, TCP连接两端的两个端点各负责一条. 当对端调用close时, 虽然本意是关闭整个两条信道,
但本端只是收到FIN包. 按照TCP协议的语义, 表示对端只是关闭了其所负责的那一条单工信道, 仍然可以继续接收数据. 也就是说, 因为TCP协议的限制,
一个端点无法获知对端的socket是调用了close还是shutdown.

对一个已经收到FIN包的socket调用read方法,
如果接收缓冲已空, 则返回0, 这就是常说的表示连接关闭. 但第一次对其调用write方法时, 如果发送缓冲没问题, 会返回正确写入(发送).
但发送的报文会导致对端发送RST报文, 因为对端的socket已经调用了close, 完全关闭, 既不发送, 也不接收数据. 所以,
第二次调用write方法(假设在收到RST之后), 会生成SIGPIPE信号, 导致进程退出.

为了避免进程退出, 可以捕获SIGPIPE信号, 或者忽略它, 给它设置SIG_IGN信号处理函数:

signal(SIGPIPE, SIG_IGN);

这样, 第二次调用write方法时, 会返回-1, 同时errno置为SIGPIPE. 程序便能知道对端已经关闭.



* `server`：

```c


int listenfd = socket(AF_INET, SOCK_STREAM, 0);

// 设置 socket 选项，INADDR_ANY 表示 0.0.0.0
struct sockaddr_in server_addr;
bzero(&server_addr, sizeof(server_addr));
server_addr.sin_family = AF_INET;
server_addr.sin_addr.s_addr = htonl(INADDR_ANY);
server_addr.sin_port = htons(SERV_PORT);

// 2 - bind ：绑定到指定地址和端口等
int rt1 = bind(listenfd, (struct sockaddr *) &server_addr, sizeof(server_addr));
if (rt1 < 0) {
	error(1, errno, "bind failed ");
}


// 3 - listen：监听该 socket
int rt2 = listen(listenfd, LISTENQ);
if (rt2 < 0) {
	error(1, errno, "listen failed ");
}

// 4 - accept：接收该 socket 的连接
int connfd;
struct sockaddr_in client_addr;
socklen_t client_len = sizeof(client_addr);

if ((connfd = accept(listenfd, (struct sockaddr *) &client_addr, &client_len)) < 0) {
	error(1, errno, "bind failed ");
}

#include "lib/common.h"

static int count;

// 注册一个信号处理器
static void sig_int(int signo) {
    printf("\nreceived %d datagrams\n", count);
    exit(0);
}

int main(int argc, char **argv) {
		// 1 - create：创建 tcp socket fd
    int listenfd;
    listenfd = socket(AF_INET, SOCK_STREAM, 0);

		// 设置 socket 选项，INADDR_ANY 表示 0.0.0.0
    struct sockaddr_in server_addr;
    bzero(&server_addr, sizeof(server_addr));
    server_addr.sin_family = AF_INET;
    server_addr.sin_addr.s_addr = htonl(INADDR_ANY);
    server_addr.sin_port = htons(SERV_PORT);

		// 2 - bind ：绑定到指定地址和端口等
    int rt1 = bind(listenfd, (struct sockaddr *) &server_addr, sizeof(server_addr));
    if (rt1 < 0) {
        error(1, errno, "bind failed ");
    }

		// 3 - listen：监听该 socket
    int rt2 = listen(listenfd, LISTENQ);
    if (rt2 < 0) {
        error(1, errno, "listen failed ");
    }

    signal(SIGINT, sig_int);
    signal(SIGPIPE, SIG_IGN);

    int connfd;
    struct sockaddr_in client_addr;
    socklen_t client_len = sizeof(client_addr);

		// 4 - accept：接收该 socket 的连接
    if ((connfd = accept(listenfd, (struct sockaddr *) &client_addr, &client_len)) < 0) {
        error(1, errno, "accept failed ");
    }

		// 5 - 不断从客户端接收消息
    char message[MAXLINE];
    count = 0;
    for (;;) {
    		// 5.1 - 读取 socket 数据
        int n = read(connfd, message, MAXLINE);
        if (n < 0) {
            error(1, errno, "error read");
        } else if (n == 0) {
            error(1, 0, "client closed \n");
        }
        message[n] = 0;
        printf("received %d bytes: %s\n", n, message);
        count++;

        char send_line[MAXLINE];
        sprintf(send_line, "Hi, %s", message);

        sleep(5);

			// 5.1 - 发送数据至 socket
        int write_nc = send(connfd, send_line, strlen(send_line), 0);
        printf("send bytes: %zu \n", write_nc);
        if (write_nc < 0) {
            error(1, errno, "error write");
        }
    }
}
```

所谓  `IO`，本质也是用户进程发起一个系统调用告诉内核自己需要读取或发送数据，然后内核会从不同的设备根据该指令进行操作。如 `read`、`write`、`recvfrom` 等等。

常见的 `IO 模型` 有：

* `BIO`：同步阻塞式 `IO`，也即 `blocking IO`，默认下所有 `socket` 都为 `BIO`。用户进程发起系统调用后，会阻塞（`blocking`）。常用模型为一个请求一个进程（或线程，线程池机制）来处理。

* `NIO`：同步非阻塞式 `IO`，也即 `non-blocking IO`。该模式下，调用方不会被阻塞，内核会返回 `EWOULDBLOCK` 的 `errno`，表示当前没有数据可读写，用户进程可以使用 `多路复用选择器` 进行轮询。`NIO` 设置方法如下：

```c
int flags = fcntl(m_sock, F_GETFL, 0);
fcntl(fd, F_SETFL, flags | O_NONBLOCK);
```

* `IO Multiplexing`：`io` 多路复用机制，最常见的如 `select`、`poll`、`epoll` 等。



所谓 `IO`



 `java NIO` 相关东西，发现其与