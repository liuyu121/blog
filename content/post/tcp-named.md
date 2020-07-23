---
title: "TCP 名词解释"
date: 2020-07-22T19:11:10+08:00
lastmod: 2020-07-22T19:11:10+08:00
draft: false
categories: ["TCP"]
tags: ["tcp"]
typora-root-url: ../../static
---

# TTL

`ip` 首部 有个  `8bits` 的域 `TTL` ，本意为 `time to live`（单位秒），具体实现时，用来表示一个 `ip` 数据报可以经过的最大路由数，所以 `IPv6` 直接重命名为了 `hop limit`，也即所谓跳数。

该值由源主机设置，每过一个路由器则减一，减至 `0` 时会被丢弃，同时发送 `ICMP` 报文通知源主机。

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

# MSL

`MSL`  也即  `Maximum segment lifetime`，表示任何报文在网络上存在的最长时间，超过这个时间报文将被丢弃。这个值需要大于 `TTL`。

`RFC 793` 中规定 `MSL` 为 `2` 分钟，实际应用中常用的是 `30秒`。

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

`MSL` 常被用于`TCP` 连接维持在 `TIME_WAIT` 的最长时间，也即 `2*MSL`。

```
$ sudo sysctl -a | grep -i tcp_orphan_retries
net.ipv4.tcp_orphan_retries = 0
```

# RTT

`RTT` 全称为 `round-trip time`，也即 `往返时间`，在 `TCP` 协议下，表示数据发送至收到对方确认接收的总时间。`TCP`会 根据一套算法动态估算 `RTT`，用与流量控制、滑动窗口收缩等


# RTO

`RTO`：`Retransmission TimeOut`，也即超时重传时间，比如 `TCP` 主动关闭方在 `FIN_WAIT_1` 下没收到对方的 `ACK` 会自动重传等。同样的，`TCP` 会根据要算法动态估算 `RTO`，所以与 `RTT` 一样，都是动态变化的。

`RTO` 与 `RTT` 直接相关，当 `RTO < RTT` 时, 将会导致过多重传；当 `RTO > RTT` 时, 如果网络状况糟糕，频繁出现丢包，重传不及时会恶化网络。综合考虑，所以一般 `RTO` 会少大于 `RTT`。

指数退避算法：每发生一次重传，`RTO` 就加倍，即 `RTO=2*RTO`。类似于滑动窗口的增大与收缩算法。

# MTU

`MTU`（`Maximum Transmission Unit`），最大传输单元。表示 `IP` 数据报经过一个物理网络所被允许的最大报文长度，其中包括了 `IP首部`(`20~60` 字节不等)，一般以太网的 `MTU` 设为 `1500` 字节，加上以太帧首部的长度 `14` 字节，也就是一个数据帧不会超过 `1500+14 = 1514` 字节。

# MSS

`MSS`（`Maximum Segment Size`），表示最大报文段，也即 `TCP` 通信双方在三次握手阶段，根据 `win` 窗口协商后得出的一个值（取双方最小值），其中不包括 `TCP`首部长度。

一般来说，`MSS = MTU - IP首部大小 - TCP首部大小`。



