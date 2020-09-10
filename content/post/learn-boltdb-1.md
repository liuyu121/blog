---
title: "Boltdb 源码学习 - 组织结构（一）"
date: 2020-09-02T15:34:42+08:00
lastmod: 2020-09-02T15:34:42+08:00
draft: false
categories: ["go"]
tags: ["go", "BoltDB", "Database"]
typora-root-url: ../../static
---


[boltDB](https://github.com/boltdb/bolt) 是用 `go` 写的一款基于本地内存的 `k-v 存储引擎`，`etcd` 底层就使用了 `boltDB`。相对于其他常见的如 `MySQL`、`redis` 等，实现的公功能较简单，所以可以通过阅读源码，加强对数据库、操作系统（特别是文件这一块）以及 `go` 语言本身的理解。

## 架构

`bolt` 主要文件如下，共 `4k+` 行，其他形如 `bolt_*` 的文件，是为了兼容各个操作系统而存在的，统一封装了不同操作系统的一些系统调用： 

```
$ wc -l `ls *.go  | grep -iv bolt_ | grep -iv test | grep -iv doc | grep -iv unix`
     777 bucket.go
     400 cursor.go
    1037 db.go
      71 errors.go
     252 freelist.go
     604 node.go
     197 page.go
     691 tx.go
    4029 total
```

其中，`errors.go` 定义的是全局错误，其他文件对应一个核心模块，后面会逐个注解。

大体架构图如下：

## 示例 demo


