---
title: "Boltdb 源码学习 - 组织结构（一）"
date: 2020-09-02T15:34:42+08:00
lastmod: 2020-09-02T15:34:42+08:00
draft: false
categories: ["go"]
tags: ["go", "BoltDB", "Database"]
typora-root-url: ../../static
---

[boltDB](https://github.com/liuyu121/bbolt) 是用 `go` 写的一款基于纯内存的 `k-v 存储引擎`，`etcd` 底层就使用了 `boltDB`。相对于其他常见的如 `MySQL`、`redis` 等，其实现的功能较简单，是一个很好的通过阅读源码，加强对数据库、操作系统文件处理等，以及 `go` 语言本身的理解。

## 架构

`boltDB` 代码不多，一般都是 `test、main` 以及一些平台兼容代码（为了兼容各个操作系统，统一封装了不同操作系统的一些系统调用），概览如下：

```
gocloc --by-file --include-lang=Go --exclude-ext=.go .
---------------------------------------------------------------------------------------
File                                 files          blank        comment           code
---------------------------------------------------------------------------------------
bucket_test.go                                        235            111           1613
cmd/bbolt/main.go                                     314            251           1571
db_test.go                                            213            147           1423
tx_test.go                                            101             74            749
db.go                                                 173            306            695
cursor_test.go                                         97             65            655
bucket.go                                             120            162            495
tx.go                                                 101            146            477
node.go                                                88            122            392
freelist_test.go                                       43             17            374
freelist.go                                            44             63            297
cursor.go                                              53             78            265
simulation_test.go                                     56             40            265
page.go                                                32             24            148
freelist_hmap.go                                       35             20            123
node_test.go                                           19             21            116
bolt_windows.go                                        20             19            102
quick_test.go                                          13             10             67
bolt_unix.go                                           12             15             66
bolt_unix_aix.go                                       12             13             65
bolt_unix_solaris.go                                   11             12             65
page_test.go                                           10              5             57
manydbs_test.go                                        12              2             53
simulation_no_freelist_sync_test.go                     3              0             44
allocate_test.go                                        6              0             25
errors.go                                              17             30             24
bolt_openbsd.go                                         4              0             23
unsafe.go                                               5             14             20
bolt_linux.go                                           2              1              7
boltsync_unix.go                                        2              2              4
bolt_386.go                                             2              2              3
bolt_amd64.go                                           2              2              3
bolt_arm64.go                                           3              3              3
bolt_mips64x.go                                         3              3              3
bolt_mipsx.go                                           3              3              3
bolt_ppc.go                                             3              3              3
bolt_ppc64.go                                           3              3              3
bolt_ppc64le.go                                         3              3              3
bolt_riscv64.go                                         3              3              3
bolt_s390x.go                                           3              3              3
doc.go                                                 13             30              1
---------------------------------------------------------------------------------------
TOTAL                                   41           1894           1828          10311
---------------------------------------------------------------------------------------

```
`bolt` 主要文件大概 `4k+` 行，其他形如 `bolt_*` 的文件： 

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


