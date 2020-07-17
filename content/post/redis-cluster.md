---
title: "Redis Cluster"
date: 2019-07-02T13:26:15+08:00
draft: false
categories: ["Redis"]
tags: ["redis","database"]
---


本文所使用 `Redis` 版本为 `Redis 5`。

## 业界方案

* [codis](https://github.com/CodisLabs/codis)：
	- 本质是个 `proxy`，通过内存保存着槽位和实例节点之间的映射关系
	- 槽位间的信息同步交给 `ZooKeeper` 管理
	- 支持一些 `MGET` 等命令，实际是自身实现了 `Merge` 功能
	- `Pipeline` 操作
	- 不支持事务、`MSETNX` 等命令

* [twemproxy](https://github.com/twitter/twemproxy)

## Redis Cluster

`Redis Cluster` 是 `Redis` 官方的集群方案，具体文档可阅读：

* [Redis cluster tutorial](https://redis.io/topics/cluster-tutorial)

* [Redis Cluster Specification](https://redis.io/topics/cluster-spec) 

大致总结下一些要点如下：

* 基本特性：全网状结构(`full mest`)，没有 `中央节点`、`调度器`、`Proxy`、`Merge` 的概念，也即是所谓的 `P2P` 架构。每个节点之间都可以通信，如 `Heartbeat`、`Failover`等。采用了一种类似 `Raft` 算法中 `term(任期)`的概念 `epoch`(纪元)，进行选举等。

* `Redis Cluster Bus`：每个 `node` 需要开启两个监听端口，举例如使用 `6379` 用于监听 `redis-client` 请求，另一个端口 `16379`（默认 6379 offset 10000） 用于 `node` 之间的通信，如选举、侦测、节点变更等等。

* `gossip protocol`：`gossip 协议`是一个`去中心化`、`容错`、`保证最终一致`性的协议。

* `node`：每个 `node` 本质是全双工的通信(基于 `TCP`)。采用了分布式架构里常见的 `选举算法`，也即 `需要大于 1/2 个节点同意`，所以最少也会存在 `3个` 主节点，而通常主节点都会挂载 `1~n` 个 `slave`，所以一般情况下，`redis-cluster` 至少有 `6` 个 `nodes`。官方文档也是以 `6` 个作为示例。

* `shard`：每个 `shard` 也即 `master-slave`架构，采用 `异步 replication` 方式进行数据同步。但不同于传统的主从架构，`master` 和 `slave` 本质也是个 `节点`，可通过协议实现角色互换等。

* `slot 机制`： 使用 `pow(2, 14) = 1684` 个 `slot`，分配至各个 `master`，针对每个 `key` 进行 `一致性 hash`，将其存储至某个 `master`。其中 `一致性 hash 算法`为：

```
HASH_SLOT = CRC16(key) mod 16384 (slot 编号 区间[0, 13683])
```
* `MOVED 指令`：在集群下任何 `node` 针对 `key` 的操作，都会根据上述算法 `move` 到 `slot` 对应的节点。`redis-client` 必须处理该指令，就像操作`单机 redis` 一样。这里可以理解为 `301 Moved Permanently`

* `ASK 指令`：当 `node` 之间发生 `MIGRATING` 或 `IMPORTING` 的时候，也即表示正在进行 `slot` 的迁移，所以需要 `ASKING`。也即是个 `中间态`，因为最终肯定是要迁移完成的（变成 `MOVED`）。这里可以理解为 `307 Temporary Redirect`

* `readonly`：如果需要在 `slave` 上读数据，那么需要显示的执行 `readonly`

* 集群操作：`redis-cli` 提供了很多关于 `cluster` 的操作，可完全代替之前的 `redis-trib.rb` 脚本。`redis-cli --cluster help`

* `client slot map table`：客户端可以自己实现 `cache the map between keys and nodes`

* `hash tags`: 因为 `key` 是分布在不同 `slot`，所以在执行如 `multi` 等操作的时候，`redis-cluster` 是不支持 `CROSSSLOT Keys` 操作的。所以它提供一种 `hash tags` 的方案用于将某些 `key` 放到同一 `slot` 的方案。

> 注意：这里使用了 `{}` 用于标记真正被 `hash` 的 `key`，第一个 `{` 与紧接着其的 `}`将被认为是 `key`。

```
127.0.0.1:8002> set {users}.xxooyu 2
OK
127.0.0.1:8002> set {users}.liuduoyu 3
OK

127.0.0.1:8000> mget {users}.xxooyu {users}.liuduoyu
-> Redirected to slot [14124] located at 127.0.0.1:8002
2
3
```
* `failover`：`redis cluster` 提供的容错机制，采取了 `ping-pong`机制进行侦测（是否超时）。：
	- 故障 failover：自动恢复集群的可用性
	- 人为 failover：支持集群的可运维操作


* `write safety`：分区可用性分析（也即网络分区了，互相不可达），需要根据当前 `client` 处于何种 `分区环境`进行分析。
	 - `the minority side`：位于小分区一端，一直在 `master` 写数据，在此期间，因为 `Failover` 机制，其他分区的某个 `slave` 提升为了 `master`。那么当分区可用后，原 `master` 的数据丢失（因为该 `master` 的 `role` 成了 `slave`）。
	
	 - `the majority side`：位于大分区一端，因为主从是异步同步的，写操作在 `master` 成功后但 `slave` 未同步完成，`master` 挂了（`master` 不可达的时间超过阈值 `node timeout` 的配置），集群通过选举，某 `slave` 为新的 `master`，那么之前写的数据丢失。

	- 这里需要注意的是，因为 `master` 之间存在心跳检测，所以当某 `master` 发现其与其他 `master` 的通信断了超过 `NODE_TIMEOUT` 后，则会拒绝 `write`，为 `readonly`。这时 `slave` 已经知道自己的 `master` 挂了，开始 `failover`，其他 `master` 在开始参与选举操作。所以如果网络分区时间大于 `node timeout`，则数据会丢失。
