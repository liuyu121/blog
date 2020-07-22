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
sudo tcpdump -nn -i lo0 port 6379  and tcp -X -s 0  > redis.log

netstat -anl | grep -i 6379 | grep -i tcp4 | grep -iv 'LISTEN'
```

重点关注 `FLAGS` 如下字段：


* [S]：`SYN`
* [F]：`FIN`
* [.]：`ACK`



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



