---
title: "TCP 名词解释"
date: 2020-07-22T19:11:10+08:00
lastmod: 2020-07-22T19:11:10+08:00
draft: false
categories: ["TCP"]
tags: ["tcp"]
typora-root-url: ../../static
---

#  MSL、TTL、RTT

## TTL

`ip` 首部 有个  `8bits` 的域 `TTL` ，本意为 `time to live`（单位秒），具体实现时，用来表示一个 `ip` 数据报可以经过的最大路由数，所以 `IPv6` 直接重命名为了 `hop limit`，也即所谓跳数。

该值由源主机设置，每过一个路由器则减一，减至 `0` 时会被丢弃，同时发送 `ICMP` 报文通知源主机。

TTL字段的目的是避免这样一种情况:无法交付的数据报一直在Internet系统上循环，而这样的系统最终会被这样的“神仙”淹没。

之所以存在 `TTL`，是为了避免无法正常交付的数据包在网络中循环，成为了 `永不消散的幽灵`，最后网络就被越来越多的这种报文淹没，无法正常工作。

因为 `8bits`，所以最多长度为 `255`，一个推荐的值是 `64`。

查看方式如下：

* `Linux`

```shell
$ cat  /proc/sys/net/ipv4/ip_default_ttl
255

$ sudo sysctl -a | grep -i 'net.ipv4.ip_default_ttl'
net.ipv4.ip_default_ttl = 255
```

* `Mac` ：

```shell
$ sysctl -a | grep -i net.inet.ip.ttl
net.inet.ip.ttl: 64
```

## MSL

`MSL`  也即  `Maximum segment lifetime`，表示任何报文在网络上存在的最长时间，超过这个时间报文将被丢弃。

`RFC 793` 中规定 `MSL` 为 `2` 分钟，实际应用中常用的是30秒，1分钟和2分钟等。

查看方式如下：

* `Linux`

```shell
$ cat /proc/sys/net/ipv4/tcp_fin_timeout
30
```

* `Mac`

```shell
$ sysctl -a | grep -i tcp | grep -i msl
net.inet.tcp.msl: 15000
```

`MSL` 常被用于`TCP` 连接维持在 `TIME_WAIT` 的最长时间，也即 `2*MSL`，这里，为什么需要  `2MSL` 呢

```
$ sudo sysctl -a | grep -i tcp_orphan_retries
net.ipv4.tcp_orphan_retries = 0
```

## RTT

`RTT` 表示 `round-trip time`，

     2MSL即两倍的MSL，TCP的TIME_WAIT状态也称为2MSL等待状态，当TCP的一端发起主动关闭，在发出最后一个ACK包后，即第3次握手完成后发送了第四次握手的ACK包后就进入了TIME_WAIT状态，必须在此状态上停留两倍的MSL时间，等待2MSL时间主要目的是怕最后一个ACK包对方没收到，那么对方在超时后将重发第三次握手的FIN包，主动关闭端接到重发的FIN包后可以再发一个ACK应答包。在TIME_WAIT状态时两端的端口不能使用，要等到2MSL时间结束才可继续使用。当连接处于2MSL等待阶段时任何迟到的报文段都将被丢弃。不过在实际应用中可以通过设置SO_REUSEADDR选项达到不必等待2MSL时间结束再使用此端口。
    
    TTL与MSL是有关系的但不是简单的相等的关系，MSL要大于等于TTL。   （MSL要大于TTL       要知道为什么？）

 3、 RTT是客户到服务器往返所花时间（round-trip time，简称RTT），TCP含有动态估算RTT的算法。TCP还持续估算一个给定连接的RTT，这是因为RTT受网络传输拥塞程序的变化而变化

 

4、 2MSL即两倍的MSL，TCP的TIME_WAIT状态也称为2MSL等待状态，当TCP的一端发起主动关闭，在发出最后一个ACK包后，即第3次握 手完成后发送了第四次握手的ACK包后就进入了TIME_WAIT状态，必须在此状态上停留两倍的MSL时间，等待2MSL时间主要目的是怕最后一个 ACK包对方没收到，那么对方在超时后将重发第三次握手的FIN包，主动关闭端接到重发的FIN包后可以再发一个ACK应答包。在TIME_WAIT状态 时两端的端口不能使用，要等到2MSL时间结束才可继续使用。当连接处于2MSL等待阶段时任何迟到的报文段都将被丢弃。不过在实际应用中可以通过设置 SO_REUSEADDR选项达到不必等待2MSL时间结束再使用此端口。对于TCP中的各种控制字段，接下来进行具体说明。

 



