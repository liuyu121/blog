---
title: "Boltdb 源码学习 - 组织结构（二）"
date: 2020-09-02T15:34:42+08:00
lastmod: 2020-09-02T15:34:42+08:00
draft: false
categories: ["go"]
tags: ["go", "BoltDB", "Database"]
typora-root-url: ../../static
---



## 架构图

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


