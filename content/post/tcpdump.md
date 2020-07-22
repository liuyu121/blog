---
title: "Tcpdump"
date: 2020-07-22T19:11:10+08:00
lastmod: 2020-07-22T19:11:10+08:00
draft: false
categories: ["TCP"]
tags: ["tcpdump"]
typora-root-url: ../../static
---


```shell
sudo tcpdump -l -vv  -nn -X -s 0 -i lo0 tcp port 6379 > redis2.log & tail -f redis.log

netstat -anl | grep -i 6379 | grep -i tcp4 | grep -iv 'LISTEN'
```

其中：

* `-l`：对标准输出进行行缓冲，也即使标准输出设备遇到一个换行符就马上把这行的内容打印出来。因为 `tcpdump` 默认会将输出写到缓冲区，只有缓冲区内容达到一定的大小，或者 `tcpdump` 退出时，才会将输出写到本地磁盘。我们为了 `tail` 查看，需要设置。

* `-vv`：更详细显示指令执行过程

* `-nn`：`-n` 不显示主机名等，`-nn` 在此之外还把端口显示为数值，否则显示端口服务名。

* `-x`：用十六进制字码列出数据包资料

* `-s` ：不设置数据包大小

* `-i`：指定网卡，这里是 `mac` 机器的 `lo0`

* `tcp port 6379`：指定为 `tcp` 协议的  `6379` 端口，因为五元组 `<协议 + 源ip + 源端口 + 目的ip + 目的端口>` 可唯一判断一个传输层协议。


重点关注 `FLAGS` 如下字段：

* `[S]`：`SYN`
* `[F]`：`FIN`
* `[.]`：表示没有 `Flag`，其实也即 `ACK`。
* `[S.]` ：表示 `SYN + ACK`，也即 `SYN` 的应答报文。
* `[F.]` ：表示 `FIN + ACK`，也即 `FIN` 的应答报文。


##  MSL、TTL、RTT

### MSL

`MSL`  也即 `Maximum segment lifetime`，表示任何报文在网络上存在的最长时间，超过这个时间报文将被丢弃。



`Linux`：

```shell
$ cat /proc/sys/net/ipv4/tcp_fin_timeout
30
```

* `Mac os x`：

```shell
$ sysctl -a | grep -i tcp | grep -i msl
net.inet.tcp.msl: 15000
```

### TTL


`ip` 头 有个 `TTL` ，也即 `time to live`，表示一个 `ip` 数据报可以经过的最大路由数（所谓的 `跳数`）。该值由源主机设置，每过一个则减一，减至 `0` 时会被丢弃。中文可以译为“生存时间”，这个生存时间是由源主机设置初始值但不是存的具体时间，而是存储了一个ip数据报可以经过的最大路由数，每经过一个处理他的路由器此值就减1，当此值为0则数据报将被丢弃，同时发送ICMP报文通知源主机。RFC 793中规定MSL为2分钟，实际应用中常用的是30秒，1分钟和2分钟等。

### RTT


`RTT` 表示 `round-trip time`

     2MSL即两倍的MSL，TCP的TIME_WAIT状态也称为2MSL等待状态，当TCP的一端发起主动关闭，在发出最后一个ACK包后，即第3次握手完成后发送了第四次握手的ACK包后就进入了TIME_WAIT状态，必须在此状态上停留两倍的MSL时间，等待2MSL时间主要目的是怕最后一个ACK包对方没收到，那么对方在超时后将重发第三次握手的FIN包，主动关闭端接到重发的FIN包后可以再发一个ACK应答包。在TIME_WAIT状态时两端的端口不能使用，要等到2MSL时间结束才可继续使用。当连接处于2MSL等待阶段时任何迟到的报文段都将被丢弃。不过在实际应用中可以通过设置SO_REUSEADDR选项达到不必等待2MSL时间结束再使用此端口。
    
    TTL与MSL是有关系的但不是简单的相等的关系，MSL要大于等于TTL。   （MSL要大于TTL       要知道为什么？）

 3、 RTT是客户到服务器往返所花时间（round-trip time，简称RTT），TCP含有动态估算RTT的算法。TCP还持续估算一个给定连接的RTT，这是因为RTT受网络传输拥塞程序的变化而变化

 

4、 2MSL即两倍的MSL，TCP的TIME_WAIT状态也称为2MSL等待状态，当TCP的一端发起主动关闭，在发出最后一个ACK包后，即第3次握 手完成后发送了第四次握手的ACK包后就进入了TIME_WAIT状态，必须在此状态上停留两倍的MSL时间，等待2MSL时间主要目的是怕最后一个 ACK包对方没收到，那么对方在超时后将重发第三次握手的FIN包，主动关闭端接到重发的FIN包后可以再发一个ACK应答包。在TIME_WAIT状态 时两端的端口不能使用，要等到2MSL时间结束才可继续使用。当连接处于2MSL等待阶段时任何迟到的报文段都将被丢弃。不过在实际应用中可以通过设置 SO_REUSEADDR选项达到不必等待2MSL时间结束再使用此端口。对于TCP中的各种控制字段，接下来进行具体说明。

 



