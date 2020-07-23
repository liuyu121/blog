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

* `SYN`：`Synchronize`，表示建立连接。
* `FIN`：`Finish`，表示关闭连接。
* `ACK`：`Acknowledge`，表示确认。
* `PSH`： `Push`，表示当前正在传输数据
* `RST`： `Reset`，表示连接重置，一方可以主动发送该状态断开连接。

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

* 此后双方基于第二个 `SYN` 建立了连接，传输数据，关闭连接；

* 这时，延时的第一个 `SYN` 又到了 `server`，然后 `server` 回复 `ACK`，又进入了 `ESTABLISHED`。但这时  `client` 不会接收这个 `ACK`，更不会发送数据了，所以导致 `server` 一直处于等待数据传输状态，直至被内核关闭。

* 而如果使用 `三次握手` 机制，此时  `server` 收不到 `client` 的 `ACK`，也不会建立连接。

为什么不是 `4` 次握手 呢，因为 `TCP` 协议允许同时发送 `ACK + SYN`，也即握手的第二步。然后通过以上分析，这里我们已经知道最少需要 `3` 次就已经可以建立了，所以，为什么还要多一次呢，浪费资源 。。。

## backlog 是什么

在上面的示意图中，我们可以看到，`server` 端有两个 `queue`：`syn queue`、`accept queue`，其含义为：

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

# KeepAlive

也即 `keep TCP alive`，因为 `TCP` 本质是基于 `传输层` 建立的连接，对 `链路层` 而言，只是，很多硬件设备会主动断开不活跃的连接，比如几大运营商、一些中间网络设备、甚至代理服务器等，都会主动 `drop` 一定时间不活跃的链接。

比如 `nginx`，默认 `75s` 关闭连接，但这里是基于 `http keep alive` 设置的：

```
Syntax:	keepalive_timeout timeout [header_timeout];
Default:	
keepalive_timeout 75s;
Context:	http, server, location
The first parameter sets a timeout during which a keep-alive client connection will stay open on the server side. The zero value disables keep-alive client connections. The optional second parameter sets a value in the “Keep-Alive: timeout=time” response header field. Two parameters may differ.

The “Keep-Alive: timeout=time” header field is recognized by Mozilla and Konqueror. MSIE closes keep-alive connections by itself in about 60 seconds.
```

此外，而且上层程序也需要对当前的连接进行探活，下面看 `reids` 的相关配置：

```
# Close the connection after a client is idle for N seconds (0 to disable)
timeout 0	


# TCP keepalive.
#
# If non-zero, use SO_KEEPALIVE to send TCP ACKs to clients in absence
# of communication. This is useful for two reasons:
#
# 1) Detect dead peers.
# 2) Take the connection alive from the point of view of network
#    equipment in the middle.
#
# On Linux, the specified value (in seconds) is the period used to send ACKs.
# Note that to close the connection the double of the time is needed.
# On other kernels the period depends on the kernel configuration.
#
# A reasonable value for this option is 300 seconds, which is the new
# Redis default starting with Redis 3.2.1.
tcp-keepalive 300
```

也即，对于 `redis` 来说，为了避免太多空闲的 `client`，最大化利用性能
# 关闭

我们使用 `client` 表示主动发起关闭方，`server` 表示被动响应关闭方。

## 四次挥手

关闭一个 `TCP` 连接，大致流程如下：

* 1、`client` 调用  `close` 发送请求关闭连接的 `FIN` 报文，此后，`client` 进入 `FIN_WAIT_1` 状态。 
  
* 2、`server` 收到 `FIN` 报文后，内核自动回复 `ACK`，然后连接进入 `CLOSE_WAIT` 状态。该状态表示该连接正在等待进程调用 `close` 关闭，此时，进程可能还有别的事情要处理。

	* `client` 收到 `ACK` 后，进入 `FIN_WAIT_2` 状态，表示等待 `server` 主动关闭连接。此时，实际上 `client` 的**发送通道已经关闭了，但连接还未关闭**。
  
* 3、当 `server` 进入 `CLOSE_WAIT` 状态时，进程继续 `read` 时会返回 `0`，通常的处理逻辑是在这个 `if (read() == 0)` 下调用 `close`，触发内核发送 `FIN` 报文，此时状态变为 `LAST_ACK`。

* 4、`client` 收到这个 `FIN` 后，内核会自动回复 `ACK`，然后连接进入 `TIME_WAIT` 状态，然后继续等待 `2MSL` 后关闭连接。

	* `server` 收到 `ACK` 后，关闭连接，至此，双方都成功关闭。

大体流程如下：

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

这里，需要强调的是：

* `TCP` 必须保证报文是有序发送的，`FIN` 报文也需要遵循这个规则，当 `发送缓冲区`还有数据没发送时，`FIN` 报文不能提前发送。

* 如果是调用  `close 函数` 主动关闭，处于 `FIN_WAIT_1` 或 `FIN_WAIT_2` 状态下的连接，则会成为 `孤儿连接`，通过  `netstat  -anp | grep -i fin` 查看，是看不到 `进程` 相关信息的。这时，即便对方继续传输数据，进程也接收不到了。也即，**这个连接已经和之前所属的进程无关了**。

* 如果是调用 `shutdown 函数` 主动关闭，`TCP` 允许在半关闭的连接上长时间传输数据，处于 `FIN_WAIT_1` 或 `FIN_WAIT_2` 状态下的连接，不是孤儿连接，进程仍然可以继续接收数据。

* 存在一种特殊情况：被动关闭方收到 `FIN` 后立即调用 `close`，那么可能会发出一个 `ACK+FIN` 报文，这样就会少一次挥手。

* 如果双方同时 `close`，双方都认为自己是 `主动关闭方`，都进入了 `FIN_WAIT_1`，然后都得到了对方的 `FIN`，此时双方会进入 `CLOSING` 状态，该状态同 `LAST_ACK` 情况相似。

## 参数调优

### 主动关闭方

看完上面的流程，针对主动关闭方，就会有些疑问了，比如，假设 `client` 一直没收到 `ACK` 怎么办，会一直处于 `FIN_WAIT_1` 状态吗？`client`  处于 `TIME_WAIT` 后如何处理？`server` 到底什么时候真正关闭连接？

下面逐个状态具体分析。

* `FIN_WAIT_1`

如果  `client` 一直没收到 `ACK`，也就会一直处于 `FIN_WAIT_1`  状态。此时，内核会根据 `net.ipv4.tcp_orphan_retries` 的配置定时重发 `FIN`，直至重试失败，直接关闭。该参数会对所有处于 `FIN_WAIT_1` 的连接生效，不仅仅是 `孤儿连接`，默认重试发送 `8` 次，也即如果没收到 `ACK`，主动关闭方会发送 `9` 次 `FIN` ！至于这个定时时间是多久，取决于当前的 `RTO`，一般是经过采样然后加权计算出来的。

```shell
## 这里，默认为 0，表示取默认值 8
net.ipv4.tcp_orphan_retries = 0

## 默认值参见头文件 /usr/include/netinet/tcp.h 定义
#define TCP_LINGER2	 8	/* Life time of orphaned FIN-WAIT-2 state */
```
所以，如果服务器有大量的 `FIN_WAIT_1`，可以考虑减少 `net.ipv4.tcp_orphan_retries` 的值，避免过多的重试。

在 `FIN_WAIT_1` 状态下，还有一个很重要的参数：`net.ipv4.tcp_max_orphans`，用来控制系统所维持的该状态下连接数的最大值。如果孤儿连接数量大于该值，新增的孤儿连接将不再走四次挥手过程，而是直接发送  `RST` 报文强制关闭该连接。

该参数主要是用来防范恶意攻击，比如攻击者恶意构造 `接收窗口为 0` 的报文，因为 `TCP` 的流量控制策略，此时不能继续发送数据了，导致 `FIN` 无法发送，然后越来越多的连接一直处于 `FIN_WAIT_1` 状态，最终系统不可用。

* `FIN_WAIT_2`

前面已经提到，`shutdown`、`close` 的关闭模式不一样，前者关闭，连接可以一直处于 `FIN_WAIT_2`  状态了；而 `close` 下的关闭，这个状态不能存在太久，取决于 `net.ipv4.tcp_fin_timeout` 参数的配置，其实这个参数控制的就是有名的 `MSL`。如果一直没收到对端发送的 `FIN`，在超过这个时间后， 这个连接会被直接关闭。

* `TIME_WAIT`

从四次挥手的过程，可以知道，`client` 收到 `server` 的 `FIN` 后，进入 `TIME_WAIT`，然后需要等待 `2MSL` 也即 `2 * net.ipv4.tcp_fin_timeout` 时间，再关闭连接。

为什么要等 `2MSL` 这么多时间呢？

从 `server` 的视角去看，发送 `FIN` 后，连接处于 `LAST_ACK` 状态，等待 `client` 的 `ACK`，再关闭连接。如果这个 `ACK` 没有到达，同样的，`server` 会根据 `net.ipv4.tcp_orphan_retries` 的配置定时重发，直至收到 `ACK` 或重试次数到达上限，再关闭该连接。

如果 `client`在发送 `ACK` 后就关闭连接，释放的端口可能被复用于新的连接，但上面提到，`server` 可能会重发 `FIN`，就干扰了新建的连接。所以需要在 `TIME_WAIT`  下保留一段时间，防止 `server` 的 `FIN` 重发，以及其他可能的数据重发，避免数据错乱。

至于为什么是 `2 倍` 的 `MSL`，而不是更多倍呢，这就是在设计时的一种平衡了。`2MSL` 下，允许对方重发一次，而如果超过 `2` 次都丢弃了，说明网络本身状况很糟糕，与其继续等待，不如主动关闭。所以与 `FIN_WAIT_2`  一样，都会在该状态下保存 `2MSL` 的时长。

```shell
## 一般设置为 30s，所以 2MSL 就为 1 分钟了
net.ipv4.tcp_fin_timeout = 30
```
`linux` 下，提供了 `net.ipv4.tcp_max_tw_buckets` 参数来控制 `TIME_WAIT` 的连接数量，超过后，新关闭的连接就不再走 `TIME_WAIT` 阶段，而是直接关闭。如果服务器的并发连接增多时，`TIME_WAIT` 状态的连接数也会变多，此时就应当调大 `tcp_max_tw_buckets`，减少不同连接间数据错乱的概率。因为系统的内存和端口号都是有限的，还可以让新连接复用 `TIME_WAIT` 状态的端口，配置 `net.ipv4.tcp_tw_reuse = 1`，同时需要双方都把 `net.ipv4.tcp_timestamps = 1`。

### 被动关闭方

被动关闭方收到 `FIN` 后进入 `CLOSE_WAIT` 状态，此时连接处于半关闭状态，**内核等待进程主动调用 `CLOSE` 关闭连接**，触发 `FIN` 给主动关闭方。如果系统中存在大量的 `CLOSE_WAIT`，说明是程序出现了问题，可以从这方面入手，比如在 `read == 0` 后忘记调用 `close` 等。

被动关闭发发出 `FIN` 后，进入 `LAST_ACK`，此时如果一直没收到对方的 `ACk`，也会重试，策略和上面提到的主动关闭发重发 `FIN` 策略一致。

查看当前网络状态分布：

```shell
netstat -n | awk '/^tcp/ {++S[$NF]} END {for(a in S) print a, S[a]}'
```

## 流程图

关闭一个 `tcp`  链接的流程图如下：

![](/img/tcp-close.png)

## 为什么需要四次

相同的问题来了，为什么需要 `4` 次挥手呢，而不是 `3` 、`5` 次？

其实本质原因与需要 `3次握手` 类似，因为 `TCP` 是一个 `全双工`（`full-duplex`）的协议，通道双方互相独立。当 `client` 关闭连接时，`server` 仍然可以在不调用  `close`  函数的状态下，继续发送数据，此时连接处于 `半关闭状态`。

* `1` 次肯定不行，`client` 根本不确定对方是否收到了自己的 `FIN`，直接关闭太简单粗暴，除非发送 `RST`。
* `2` 次的话，`server` 不能保证能立即关闭，因为其可能需要继续处理、发送数据等。
* `3`次时，同理，`server` 也不能保证 `client` 收到了自己的 `FIN`。

所以，因为是 `全双工`，所以一来一回`*2`，最少需要`4次` 握手机制，才能保证一个连接正确关闭。

在 `web` 应用中，大多情况下，**服务器才是主动关闭连接的一方**，比如 `nginx`。这是因为 `HTTP` 消息是单向传输协议，服务器接收完请求才能生成响应，发送完响应后就会立刻关闭 `TCP` 连接，及时释放资源，才能够承载更多的用户请求。

# 代码示例


# 参考

最后，用一张图结束本文：

![](/img/tcp.png)

参考：

* [wikipedia - TCP](https://en.wikipedia.org/wiki/Transmission_Control_Protocol)

* [How TCP backlog works in Linux](http://veithen.io/2014/01/01/how-tcp-backlog-works-in-linux.html)

* [How TCP backlog works in Linux - 中文翻译](https://www.cnblogs.com/grey-wolf/p/10999342.html)

* [TCP-Keepalive-HOWTO](http://www.tldp.org/HOWTO/html_single/TCP-Keepalive-HOWTO/)

* [半连接队列和全连接队列]([https://plantegg.github.io/2017/06/07/%E5%B0%B1%E6%98%AF%E8%A6%81%E4%BD%A0%E6%87%82TCP--%E5%8D%8A%E8%BF%9E%E6%8E%A5%E9%98%9F%E5%88%97%E5%92%8C%E5%85%A8%E8%BF%9E%E6%8E%A5%E9%98%9F%E5%88%97/](https://plantegg.github.io/2017/06/07/就是要你懂TCP--半连接队列和全连接队列/))

* [从一次 Connection Reset 说起，TCP 半连接队列与全连接队列](https://cjting.me/2019/08/28/tcp-queue/)

* [TCP 半连接队列和全连接队列满了会发生什么？又该如何应对？](https://www.cnblogs.com/xiaolincoding/p/12995358.html)

* [TCP SOCKET中backlog参数的用途是什么？](https://www.cnxct.com/something-about-phpfpm-s-backlog/)

* [详解Nginx中HTTP的keepalive相关配置](https://blog.51cto.com/welcomeweb/1931087)