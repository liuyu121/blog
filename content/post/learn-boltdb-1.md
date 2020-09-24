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

## 组织结构

`boltDB` 代码不多，一般都是 `test、main` 以及一些平台兼容代码（为了兼容各个操作系统，统一封装了不同操作系统的一些系统调用），概览如下：

```
> gocloc --by-file --include-lang=Go --exclude-ext=.go .
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
> wc -l `ls *.go  | grep -iv bolt_ | grep -iv test | grep -iv doc | grep -iv unix`
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
文件与目录组织结构如下：

```shell
> tree
.
├── LICENSE
├── Makefile
├── README.md
├── allocate_test.go
├── bolt_386.go
├── bolt_amd64.go
├── bolt_arm.go
├── bolt_arm64.go
├── bolt_linux.go
├── bolt_mips64x.go
├── bolt_mipsx.go
├── bolt_openbsd.go
├── bolt_ppc.go
├── bolt_ppc64.go
├── bolt_ppc64le.go
├── bolt_riscv64.go
├── bolt_s390x.go
├── bolt_unix.go
├── bolt_unix_aix.go
├── bolt_unix_solaris.go
├── bolt_windows.go
├── boltsync_unix.go
├── bucket.go
├── bucket_test.go
├── cmd
│   └── bbolt
│       ├── main.go
│       └── main_test
├── cover.out
├── cursor.go
├── cursor_test.go
├── db.go
├── db_test.go
├── doc.go
├── errors.go
├── freelist.go
├── freelist_hmap.go
├── freelist_test.go
├── go.mod
├── go.sum
├── manydbs_test.go
├── node.go
├── node_test.go
├── page.go
├── page_test.go
├── quick_test.go
├── simulation_no_freelist_sync_test.go
├── simulation_test.go
├── tx.go
├── tx_test.go
└── unsafe.go

2 directories, 49 files
```
其中，`errors.go` 定义的是全局错误，其他文件对应一个核心模块，后面会逐个注解。

`cmd/bbolt/main.go` 封装了 `bolt` 命令行参数，代码组织格式类似，实现了各大命令行的使用：

```shell
> bbolt
Bolt is a tool for inspecting bolt databases.

Usage:

	bolt command [arguments]

The commands are:

    bench       run synthetic benchmark against bolt
    buckets     print a list of buckets
    check       verifies integrity of bolt database
    compact     copies a bolt database, compacting it in the process
    dump        print a hexadecimal dump of a single page
    get         print the value of a key in a bucket
    info        print basic info
    keys        print a list of keys in a bucket
    help        print this screen
    page        print one or more pages in human readable format
    pages       print list of pages with their types
    page-item   print the key and value of a page item.
    stats       iterate over all pages and generate usage stats

Use "bolt [command] -h" for more information about a command.
```

## 主要模块关系

db.open

