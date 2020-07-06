---
title: "Mysql Metadata Lock"
date: 2019-07-31T17:24:04+08:00
draft: false
categories: ["MySQL"]
tags: ["mysql","database", "mysql 锁"]
---


环境说明

* MySQL 版本：`5.7.11`

* 存储引擎：`ENGINE=InnoDB`

注：`MySQL` 在 `5.5.3` 版本引入了 `MDL`锁（`metadata-lock`）

## 场景复现

开启多个 `mysql shell`：

* 测试准备：

```sql
use test;
CREATE TABLE `test_metadata_lock` (
  `id` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
```

* session A：开启一个事务，但不提交

```sql
localhost@test > select * from test_metadata_lock;
+------+
| id   |
+------+
|  123 |
+------+
1 row in set (0.00 sec)

localhost@test > select connection_id();
+-----------------+
| connection_id() |
+-----------------+
|             246 |
+-----------------+
1 row in set (0.00 sec)

localhost@test > begin;
Query OK, 0 rows affected (0.00 sec)

localhost@test > select * from test_metadata_lock;
+------+
| id   |
+------+
|  123 |
+------+
1 row in set (0.00 sec)
```
* session B：会阻塞

```sql
localhost@test > select connection_id();
+-----------------+
| connection_id() |
+-----------------+
|             247 |
+-----------------+
1 row in set (0.00 sec)

localhost@test > alter table test_metadata_lock add column (name varchar(255) not null default '');
```
* session C：查看当前进程，发现 `247` 存在 `metadata-lock`

```sql
localhost@test > show processlist;
+-----+------+-----------+------+---------+------+---------------------------------+-----------------------------------------------------------------------------------+
| Id  | User | Host      | db   | Command | Time | State                           | Info                                                                              |
+-----+------+-----------+------+---------+------+---------------------------------+-----------------------------------------------------------------------------------+
| 246 | root | localhost | test | Sleep   |  132 |                                 | NULL                                                                              |
| 247 | root | localhost | test | Query   |   48 | Waiting for table metadata lock | alter table test_metadata_lock add column (name varchar(255) not null default '') |
| 248 | root | localhost | test | Query   |    0 | starting                        | show processlist                                                                  |
+-----+------+-----------+------+---------+------+---------------------------------+-----------------------------------------------------------------------------------+
```

## 解释

`metadata lock` 主要为了保证元数据的一致性，用于处理不同线程操作同一数据对象的同步与互斥问题。可参考 `MySQL 官方文档`  [^pa1]，相关 `bug`  [^pa2]。

* 事务隔离（5.5 之前的版本）：比如在可重复读隔离级别（`RR`）下，`session A` 在 2 次查询期间，`session B` 对表结构做了修改，两次查询结果就会不一致，无法满足可重复读的要求。

* 数据复制问题：比如 `session A` 执行了多条更新语句，`session B`做了表结构变更并且先提交，就会导致 `slave` 在重做时，因为先重做 `alter`，再重做 `update`，会出现复制错误的现象。

需要注意的是，如果 `sql` 本身存在错误（非语法错误），也会造成 `metadata-lock`：

* `session A`：`select` 一个不存在的字段，事务没有开始，但是失败语句获取到的锁依然有效。

```sql
localhost@test > set autocommit=0;
Query OK, 0 rows affected (0.05 sec)

localhost@test > select t from test_autocommit;
ERROR 1054 (42S22): Unknown column 't' in 'field list'
```

* `session B`：`alter table` 阻塞。

```sql
localhost@test > alter table test_autocommit add column (name varchar(255) not null default '');
```

* `session C`：

```sql
localhost@test > select * from information_schema.processlist where state = 'Waiting for table metadata lock';
+-----+------+-----------+------+---------+------+---------------------------------+--------------------------------------------------------------------------------+
| ID  | USER | HOST      | DB   | COMMAND | TIME | STATE                           | INFO                                                                           |
+-----+------+-----------+------+---------+------+---------------------------------+--------------------------------------------------------------------------------+
| 247 | root | localhost | test | Query   |  168 | Waiting for table metadata lock | alter table test_autocommit add column (name varchar(255) not null default '') |
+-----+------+-----------+------+---------+------+---------------------------------+--------------------------------------------------------------------------------+
```

但如果是语法错误，`session B` 不会阻塞：

* `session A`：语法错误。

```sql
localhost@test > select1 t from test_autocommit;
ERROR 1064 (42000): You have an error in your SQL syntax; check the manual that corresponds to your MySQL server version for the right syntax to use near 'select1 t from test_autocommit' at line 1
```
* `session B`：执行成功。

```sql
localhost@test > alter table test_autocommit add column (name varchar(255) not null default '');
Query OK, 0 rows affected (0.24 sec)
Records: 0  Duplicates: 0  Warnings: 0
```

官方对此说明为：

> If the server acquires metadata locks for a statement that is syntactically valid but fails during execution, it does not release the locks early. Lock release is still deferred to the end of the transaction because the failed statement is written to the binary log and the locks protect log consistency.

[^pa1]: [MySQL 官方文档](https://dev.mysql.com/doc/refman/5.7/en/metadata-locking.html)

[^pa2]: [bug#989](https://bugs.mysql.com/bug.php?id=989)