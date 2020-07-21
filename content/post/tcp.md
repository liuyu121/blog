---
title: "TCP 连接的建立与关闭"
date: 2020-07-16T14:03:29+08:00
lastmod: 2020-07-16T14:03:29+08:00
draft: false
categories: ["TCP"]
tags: ["tcp"]
typora-root-url: ../../static
---

`tcp（Transmission Control Protocol）` 是一种位于传输层、面向字节流、保证可靠传输的全双工协议，作为底层协议，支撑着着应用层如 `http`、`SMTP` 等。鼎鼎大名的 `三次握手`、`四次挥手`指的就是其建立与关闭的流程。

`tcp` 协议的生命周期，本质是一个*有限状态机* 的流转，从建立到数据传输再到关闭，伴随着不同状态的迁移。而在不同的状态中，又会有着一些优化与问题。

`tcp 协议`  本身极其复杂，除了建立与关闭涉及到多次交互外，还需要考虑  `差错检测`、`滑动窗口`、`重传策略`、`拥塞控制`、`RTT（Round Trip Time）`、`MSS(maximum segment size)` 等等，远古大神们真是费煞苦心。

注：本文的图例来自网络，历史原因未标明出处，感谢原作者们清晰的图示 :)

# 首部结构

`tcp` 报文首部格式如下：

![](/img/tcp-segment-header.png)

其中，在日常分析 `tcp` 的建立与关闭时，主要关注的是在 `FLAGS `字段，该字段也即所谓的 `tcp 状态机`，主要有如下字段（大写表示，与序列号区分开）：

* `SYN`：`Synchronize Sequence Numbers`，同步序列号，表示建立连接。
* `FIN`：表示关闭连接。
* `ACK`：`Acknowledge Sequence Numbers`，确认序列号，表示响应。
* `PSH`： `push`，表示当前正在传输数据
* `RST`： `reset`，表示连接重置。

然后，有两个重要的 `32位` 序列号：

* `seq`：`Sequence number`，表示序列号，用来保证数据的有序传输。
  * 如果 `SYN` 设置为 `1`，其表示 `ISN（initial sequence number）`，也即，初始序列号，并期望对方能返回该 `ISN+1`  的 `ack`。
  * 如果 `SYN` 设置为 `0`，表示当前传输报文段中首字节的编号（在当前全部字节流中，通过 `mss` 分段后的编号。

* `ack`： `Acknowledgment number (if ACK set)`
  * 当且仅当 `ACK` 设置为  `1` 时，才有效。
  *  表示期望收到的下一个 `seq`，如果是 `SYN` 的 `ACK`，其值为发起方的 `ISN+1`。

#  建立

我们使用 `client` 表示主动发起建立方，`server` 表示被动响应建立方，`server` 需要 `bind` 某个端口并 `listen`，做好随时迎接一个连接的准备。

一个连接的建立，大体流程如下：

* 1、`client` 发送请求建立连接的报文，其中 `SYN = 1` ，`seq`  为一个随机值  `ISN1` ，注意这里必须是随机值而不能设为 `1`，防止被猜测序列号后恶意攻击（也即所谓的「`TCP序列猜测攻击`」）。
  * 此时，`client` 进入 `SYN_SENT` 状态。 
* 2、`server` 收到请求报文后，发送一个 `SYNC = 1, ACK = 1`，也即 `SYN+ACK`，且同样的，随机一个  `ISN2` 作为 `seq`，并设 `ack = ISN1+1`，也即对请求报文的确认。其中 `ack` 表示希望 `client` 接下来传该字节开始的数据流。
  * 此时，`server` 进入 `SYN_RECEIVED` 状态。
* 3、`client` 收到响应报文后，需要再次确认，发送一个 `ACK = 1`，并设 `ack = ISN2+1，seq = ISN1+1`，也即表示自己收到了 `server` 的确认报文。这里，`seq = ISN1+1`  是因为，从语义上来说，`server` 希望收到该序号的报文。
  * 此时，`client` 进入 `ESTABLISHED` 状态，`server` 在收到 `ACK` 后也进入  `ESTABLISHED` 状态。

自此，我们可以认为双方进入 `ESTABLISHED` 状态，全双工连接建立完成。但其实，这里准确的说，应该是 `client` 进入了  `ESTABLISHED` 状态，`server` 是否成功还取决于当前 `accept queue` 的情况，下面会具体分析。

需要注意的是，上面的流程中，并没有真正的发送数据（最后一次握手客户端可以携带数据），双方只是进行一系列序列号交换的握手操作。

整体示意图如下：
![](/img/tcp-connect.jpeg)

## 为什么是三次握手

为什么是三次握手，而不是不是`2` 次或`4` 次呢？

从建立的流程可以看出，`第一次` 发送，表示 `client` 请求建立连接；第二次表示 `server` 收到了请求并做了回复。这里如果没有第三次就  `ESTABLISHED`  了，开始传输数据，那么会有什么问题呢？

这里，我们需要重点关注 `seq` ，`tcp` 就是依据这个字段进行所谓 `可靠传输` 的，也即，`tcp` 双方都依赖这个序列号来进行数据包的有序传输。从语义上来说，参与 `TCP` 连接的双方，都需要满足：

*  知道对方下一个要发的包序列（对方 `seq`）
*  知道对方收到了自己之前发出的包（我方 `seq`）

所以，在前两次握手完成后，双方都进入 `ESTABLISHED`，此时：

* `client` 得到了正确的返回 `ISN1+1`，且得到了 `server` 的 `seq`，也即 `cient` 知道 `server` 已经收到自己的数据包了，且知道 `server` 下一个要发的序列；

* `server` 不确定自己的 `ACK`  是否成功被 `client` 接收，假设这时这个包丢了，此时，`client`  不知道 `server` 的 `seq`， `server`  就无法保证  `client`   是按照正确的顺序来接收自己的数据包。也即，如果 `server` 继续发送数据，`client` 无法做到有序接收。

以上，不满足 `TCP` 的语义要求。

另外，还有其他场景，如：

* `client` 先后发送了两次 `SYN`，第一个 `SYN` 延时了，第二个 `SYN` 先行到达 `server`；

* 此后双方建立了连接，传输数据，关闭连接；

* 这时，延时的第一个 `SYN` 又到了 `server`，然后 `server` 回复 `ACK`，又进入了 `ESTABLISHED`。但其实这是个无效的报文，建立了一个多余的连接。

* 而如果使用 `三次握手` 机制，此时  `client` 可以直接丢弃该无效报文，而 `server` 收不到 `client` 的 `ACK`，也不会建立连接。

为什么不是 `4` 次握手 呢，但这里我们已经知道最少需要 `3` 次就已经可以建立了，所以，为什么还要多一次呢，浪费资源 。。。

## backlog 是什么

在上面的示意图中，我们可以看到，`server` 端有两个 `queue`：`syn queue`、`accept queue`，其含义为:

* `syn queue`：半连接队列（`Half-open Connection`)。当 `server` 收到 `SYN` 报文后（`>=1` 个），内核需要维护这些连接，所以需要一个队列保存下来，也即这里的 `syn queue`，同时发送 `SYN+ACK` 给 `client`。
  * 队列未满：加入到 `sync queue`。
  * 队列已满：如果  `net.ipv4.tcp_syncookies = 0`，直接丢弃这个包，如果设置了该参数，则：

    * 如果 `accept queue` 也已经满了，并且 `qlen_young` 的值大于 1，丢弃这个 `SYN`；其中，`qlen_young` 表示目前 `syn queue` 中，没有进行 `SYN+ACK` 包重传的连接数量。

    * 否则，生成 `syncookie` 并返回 `SYN+ACK`。

  * 可构造 `TCP SYN FLOOD` 攻击，发送大量的 `SYN` 报文，然后丢弃，导致 `server` 的该队列一直处于满负荷状态，无法处理其他正常的请求。 
* `accept queue`：全连接队列。当 `server` 再次收到  `client` 的 `ACK` 后，这时，如果：

  * 队列未满：将该连接放入到全连接队列中，系统调用 `accept` 本质就是从该队列不断获取已经连接好的请求。
  
  * 队列已满：取决于 `tcp_abort_on_overflow` 的配置
  
    * `tcp_abort_on_overflow = 0`：`server` 丢弃该 `ACK`，再由一个定时器  `net.ipv4.tcp_synack_retries` 重传 `SYN+ACK` ，总次数不超过 `/proc/sys/net/ipv4/tcp_synack_retries`  配置的次数。
    
    * 这是因为此时 `server` 还处于 `SYN_RECEIVED` 状态，所以再次发送报文告诉 `client` 可以重新尝试建立连接（可能  `server` 下一次收到该包时队列变成未满状态了 ）。此时，若 `client` 的超时时间较短，则表现为 `READ_TIMEOUT`，因为 `client` 已经处于 `ESTABLISHED` 了。
    
    * `tcp_abort_on_overflow = 1`：`server` 回复 `RST`，并从半连接队列中删除，`client` 表现为 `Connection reset by peer`

这里的逻辑比较复杂，涉及到内核很多参数的设置，具体可以参考相关书籍，下面是更清晰的图示：

![](/img/tcp-queue.png)

我们回到标题的 `backlog` 上，之所以重点关注这个参数，是因为在日常的 `web 开发` 中，涉及到的 `nginx + redis + php-fpm` 等，配置项大多都有这个参数，而这些软件都是典型的  `server-client` 结构。

`server` 监听函数 `listen` 原型如下（`man listen`），这里第二个参数就是我们要讨论的 `backlog`：

```c
       int listen(int sockfd, int backlog);
```

这个 `backlog` 参数，定义是 *已连接但未进行 `accept` 处理的 `SOCKET` 队列大小*，也即上面提到的 `accept queue`。如果这个队列满了，将会发送一个 `errno = ECONNREFUSED` 的错误，即 `linux` 头文件 `/usr/include/asm-generic/errno.h` 中定义的 `Connection refused`。

接下来分别看下常用软件的设置：

* `nginx`：默认为 `511`

```
backlog=number
sets the backlog parameter in the listen() call that limits the maximum length for the queue of pending connections. By default, backlog is set to -1 on FreeBSD, DragonFly BSD, and macOS, and to 511 on other platforms.
```

* `redis`：默认为 `511`

```
# TCP listen() backlog.
#
# In high requests-per-second environments you need an high backlog in order
# to avoid slow clients connections issues. Note that the Linux kernel
# will silently truncate it to the value of /proc/sys/net/core/somaxconn so
# make sure to raise both the value of somaxconn and tcp_max_syn_backlog
# in order to get the desired effect.
tcp-backlog 511
```

* `php-fpm`：默认为 `511`

```
; Set listen(2) backlog.
; Default Value: 511 (-1 on FreeBSD and OpenBSD)
;listen.backlog = 511
```

所以，我们 *惊奇* 的发现，三者的默认值都为 `511`，但其实之前 `php-fpm` 设置的是 `65535`，后来在某个版本中 `fix` 了，`issue` 参见 [Set FPM_BACKLOG_DEFAULT to 511](https://github.com/php/php-src/commit/ebf4ffc9354f316f19c839a114b26a564033708a)。

那么，为什么要 `fix` 这个数值呢，我们可做如下推理：

* 如果 `php-fpm` 的 `backlog` 过大，通过 `nginx` 的请求可以一直建立，但如果 `php` 的处理速度变慢了，后面的连接执行时间过长，可能超出了 `nginx` 的 `fastcgi_read_timeout` 设置，`fpm` 往这个 `socket`  `write` 时，`nginx` 已经断开了连接了， 会出现  `broken pipe` 错误，也即 `Connection timed out`，`nginx` 表现为 `504 Gateway Timeout`

* 如果 `php-fpm` 的 `backlog` 过小， `nginx` 的请求超过 `fastcgi_connect_timeout` 时间还未建立，，也即 `Connection refused`， `nginx` 表现为 `502 Bad Gateway` 错误。

所以， `php-fpm` 的就设置为 `nginx` 一样，`511`，因为内核源码的判断条件是 `>`，因而这些常见的应用最多能 `accept 512` 个请求。

# 关闭

我们使用 `client` 表示主动发起关闭方，`server` 表示被动响应关闭方。

关闭一个 `TCP` 连接，大致流程如下：

* 1、`client` 发送请求关闭连接的报文，其中 `FIN = 1, seq = x`。
  
  * 此时，`client` 进入 `FIN_WAIT_1` 状态。 
  
* 2、`server` 收到 `FIN` 报文后，发送一个 `ACK = 1, ack = x+1`，表示已经收到了关闭的请求。注意，这里不是立即关闭，因为此时可能还要别的数据要接收、处理等。
  
  * 此时，`server` 进入 `CLOSE_WAIT` 状态；`client` 收到 `ACK` 后 进入 `FIN_WAIT_2` 状态。
  
* 3、`server` 处理完了当前工作，可以关闭了，发送一个 `FIN = 1, seq = y` 的报文，然后等待 `client` 的响应，就可以关闭当前连接了。

  * 此时，`server` 进入 `LAST_ACK` 状态。
  
* 4、`client` 收到 `FIN` 报文，发送一个 `ACK = 1, seq = y+1`，此时 

	* 此时，`client`  进入 `TIME_WAIT` 状态，等待一段时间后，关闭连接；`server` 收到 `ACK`  关闭连接；

```
	TCP A                                   	TCP B

  1.  ESTABLISHED                                       ESTABLISHED

  2.  (Close)
      FIN-WAIT-1  --> <SEQ=100><ACK=300><CTL=FIN,ACK>  --> CLOSE-WAIT

  3.  FIN-WAIT-2  <-- <SEQ=300><ACK=101><CTL=ACK>      <-- CLOSE-WAIT

  4.                                                       (Close)
      TIME-WAIT   <-- <SEQ=300><ACK=101><CTL=FIN,ACK>  <-- LAST-ACK

  5.  TIME-WAIT   --> <SEQ=101><ACK=301><CTL=ACK>      --< CLOSED

  6.  (2 MSL)
      CLOSED
```

关闭一个 `tcp`  链接的流程图如下：

![](/img/tcp-close.png)

## 为什么需要四次

相同的问题来了，为什么需要 `4` 次挥手呢，而不是 `3` 、`5` 次？

其实本质原因与需要 `3次握手` 类似，因为 `TCP` 是一个 `全双工`（`full-duplex`）的协议。

* `1` 次肯定不行，`client` 根本不确定对方是否收到了自己的 `FIN`，直接关闭太简单粗暴
* `2` 次的话，`server` 不能保证能立即关闭，因为其需要一个处理当前逻辑的时间
* `3`次时，同理，`server` 也不能保证 `client` 收到了自己的 `FIN`

所以，因为是 `全双工`，所以一来一回`*2`，最少需要`4次` 握手机制，才能保证一个连接正确关闭。

## TIME_WAIT 与 CLOSE_WAIT

`TIME_WAIT` 与 `CLOSE_WAIT` 应该是 `web` 服务中，最常见的几个 `TCP` 状态，通常，也是我们需要重点关注的网络指标。

# 代码示例


# 参考

最后，用一张图结束本文：

![](/img/tcp.png)

下面有一些有用到文章，都是干货。

* [wikipedia - TCP](https://en.wikipedia.org/wiki/Transmission_Control_Protocol)
* [How TCP backlog works in Linux](http://veithen.io/2014/01/01/how-tcp-backlog-works-in-linux.html)
* [How TCP backlog works in Linux - 中文翻译](https://www.cnblogs.com/grey-wolf/p/10999342.html)
* [就是要你懂TCP--半连接队列和全连接队列]([https://plantegg.github.io/2017/06/07/%E5%B0%B1%E6%98%AF%E8%A6%81%E4%BD%A0%E6%87%82TCP--%E5%8D%8A%E8%BF%9E%E6%8E%A5%E9%98%9F%E5%88%97%E5%92%8C%E5%85%A8%E8%BF%9E%E6%8E%A5%E9%98%9F%E5%88%97/](https://plantegg.github.io/2017/06/07/就是要你懂TCP--半连接队列和全连接队列/))
* [从一次 Connection Reset 说起，TCP 半连接队列与全连接队列](https://cjting.me/2019/08/28/tcp-queue/)
* [TCP 半连接队列和全连接队列满了会发生什么？又该如何应对？](https://www.cnblogs.com/xiaolincoding/p/12995358.html)

* [TCP SOCKET中backlog参数的用途是什么？](https://www.cnxct.com/something-about-phpfpm-s-backlog/)