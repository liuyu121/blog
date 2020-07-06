---
title: "Mysql Proxy"
date: 2018-08-26T15:44:49+08:00
draft: false
categories: ["MySQL"]
tags: ["mysql","database"]
---

HA：High Available

## `Mysql proxy`

`Mysql proxy` 的意义在于：

* 单机数据库不满足需求，需要多实例、多机部署
* 基于 `mysql server` 与 `client` 的中间层，对前端透明，对 `DB` 则是一个客户端
* 读写分离
* 分表路由
* 连接池
* `sql 黑名单`：如 不带 `where` 条件的 `update`、`insert` 等语句。
* `web 化` 的管理界面

下面是一些开源的技术方案。

* [mysql-proxy](https://github.com/mysql/mysql-proxy)：`Mysql` 官方的方案

* [druid](https://github.com/alibaba/druid)：阿里巴巴开源的数据库连接池

* [Atlas](https://github.com/Qihoo360/Atlas)：奇虎360开源的 `Mysql proxy`，基于 [mysql-proxy]

* [Mycat-Server](https://github.com/MyCATApache/Mycat-Server)：国内开源社区的集成方案，基于原阿里中间件 `Cobar` 进行的二次开发。


## `uuid`

关于 `全局id` 的生成，也即有很多方案，目的是为了构造一个全局的、趋势递增、独一无二的 `整型id`。

大体思想是以 `命名空间` 形式构造：

```
版本号 + 时间 + 机器号 + 序列号(一个自增序列)
```

因为是基于 `时间`，所以会存在 `时钟回拨` 的问题。

* [snowflake](https://github.com/twitter-archive/snowflake) ：`twittter` 开源的 `uuid` 生成算法。

* [uid-generator](https://github.com/baidu/uid-generator)：百度开源的 `uuid` 生成方案，基于 `snowflake`。

* [Leaf](https://github.com/Meituan-Dianping/Leaf)：美团开源的方案，具体可参见其技术文章：[Leaf——美团点评分布式ID生成系统](https://tech.meituan.com/2017/04/21/mt-leaf.html)