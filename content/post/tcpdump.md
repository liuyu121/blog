---
title: "tcpdump"
date: 2020-07-22T19:11:10+08:00
lastmod: 2020-07-22T19:11:10+08:00
draft: false
categories: ["TCP"]
tags: ["TcpDump", "TCP"]
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

