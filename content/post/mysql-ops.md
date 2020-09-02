---
title: "MySQL 语句类型以及提交类型"
date: 2017-03-16T14:18:07+08:00
draft: false
categories: ["MySQL"]
tags: ["MySQL","Database"]
---


## 一、sql 语句类型

### 1.1 DQL 

> DQL : Data Query Language

`DQL` 也即 `数据查询语言`，语法定义为：

```sql
SELECT select_list
[ INTO new_table ]
FROM table_source
[ WHERE search_condition ]
[ GROUP BY group_by_expression ]
[ HAVING search_condition ]
[ ORDER BY order_expression [ ASC | DESC ] ]
```
举例：

* 查找订单表总消费大于 1000 元的用户，按照消费金额从大到小排序：

```sql
select user_id, sum(price) total 
from orders
where status = 1
group by user_id
having total > 1000 * 100
order by total desc;
```

### 1.2 DML 

> DML : Data Manipulation Language

`DML` 也即 `数据操纵语言`，有三种形式：

* INSERT：插入
* UPDATE：更新
* DELETE：删除

### 1.3 DDL 

> DDL : Data Definition Language

`DDL` 也即 `数据定义语言`，主要是用来操作数据库、表、视图等的一系列语句，如

* CREATE 语句：创建数据库、表、视图等
	- CREATE DATABASE
	- CREATE TABLE
	- CREATE VIEW

* ALTER 语句：修改表、视图等
	- ALTER TABLE
	- ALTER VIEW

* DROP 语句：删除表、视图等
	- DROP TABLE
	- DROP VIEW

* TRUNCATE：重置表

> 务必注意：`DDL` 操作是 `隐性提交` 的，不能 `rollback`。

### 1.4 DCL 

> DCL : Data Control Language

`DCL` 也即 `数据控制语言`，是用来设置、更改数据库用户、角色权限等的一系列语句。

最常用的如：

* GRANT：授予访问权限

```sql
GRANT SElECT ON test.* TO 'test'@'127.0.0.1' IDENTIFIED BY "readonly";
```
* REVOKE：撤销访问权限

* COMMIT：事务提交

* ROLLBACK：事务回滚；

* SAVEPOINT：设置保存点

* LOCK：对数据库的特定部分进行锁定，如 `lock table`

## 二、显式提交、隐式提交、自动提交

> 注：环境说明

* `MySQL` 版本：`5.7.11`
* 存储引擎：` ENGINE=InnoDB`
* 隔离级别：`RR`（`REPEATABLE-READ`）：

### 2.1 显示提交

`commit` 语句用来显示提交一个事务，标准用法为：

```sql
begin;

commit | rollback;
```

当且仅当执行了该命令，数据库才会将之前的语句真实提交。

具体单机事务的提交，可以参考其他资料，如在 `innoDB` 下，存在 `2PC 机制`，以及 `undo log`、`redo log`、`binlog`等文件的写入机制。

### 2.2 隐式提交

一些 `SQL` 命令的提交，是隐式提交，也即会自动提交，最常见的如：

* `DDL语句`
* 嵌套事务：尤为要注意是否在代码中存在嵌套事务。

> 详细语句可参考 [导致隐式提交的语句 ](https://www.docs4dev.com/docs/zh/mysql/5.7/reference/implicit-commit.html)

`隐式提交` 可能导致一些异常现象，下面举例说明：

> 开启多个 `mysql session`，按照如下顺序执行语句。

* `session A`：

```sql
localhost@test > select @@autocommit;
+--------------+
| @@autocommit |
+--------------+
|            1 |
+--------------+
1 row in set (0.00 sec)

localhost@test > create table test_yinshi_commit(`id` int(11));
Query OK, 0 rows affected (0.05 sec)

localhost@test > show create table test_yinshi_commit\G
*************************** 1. row ***************************
       Table: test_yinshi_commit
Create Table: CREATE TABLE `test_yinshi_commit` (
  `id` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8
1 row in set (0.01 sec)

localhost@test > begin;
Query OK, 0 rows affected (0.00 sec)

localhost@test > insert into test_yinshi_commit values(1);
Query OK, 1 row affected (0.00 sec)

localhost@test > select * from test_yinshi_commit;
+------+
| id   |
+------+
|    1 |
+------+
1 row in set (0.00 sec)

localhost@test > rollback;
Query OK, 0 rows affected (0.00 sec)

localhost@test > select * from test_yinshi_commit;
Empty set (0.00 sec)
```

* `session B`：

```sql
localhost@test > select * from test_yinshi_commit;
Empty set (0.01 sec)
```

接下来，我们在事务中，添加一个 `DDL` 语句，注意观察不同。

* `session A`：注意，这时事务并未提交。

```sql
localhost@test > begin;
Query OK, 0 rows affected (0.00 sec)

localhost@test > select * from test_yinshi_commit;
Empty set (0.00 sec)

localhost@test > insert into test_yinshi_commit values(1);
Query OK, 1 row affected (0.00 sec)

localhost@test > select * from test_yinshi_commit;
+------+
| id   |
+------+
|    1 |
+------+
1 row in set (0.00 sec)

localhost@test > create table test_yinshi_commit2(`id` int(11));
Query OK, 0 rows affected (0.04 sec)

localhost@test > select * from test_yinshi_commit;
+------+
| id   |
+------+
|    1 |
+------+
1 row in set (0.00 sec)
```

* `session B`：A 事务未提交，但已经可以获取数据。

```sql
localhost@test > select * from test_yinshi_commit;
+------+
| id   |
+------+
|    1 |
+------+
1 row in set (0.01 sec)
```

* `session A`：回滚事务，但数据已经提交了。

```sql
localhost@test > rollback;
Query OK, 0 rows affected (0.00 sec)

localhost@test > select * from test_yinshi_commit;
+------+
| id   |
+------+
|    1 |
+------+
1 row in set (0.00 sec)
```

通过观察上述情况，我们发现，第二处 `rollback` 并没起到作用。其实事务在 `create table` 语句提交后，已经 `commit` 了。

也即，`DDL 语句`会进行`隐式提交`，因为 `DDL 语句`是数据定义语言，起着创建、删除、修改数据库的作用，对数据的影响较为复杂，所以为了简单实现，保证数据库的一致性，防止阻塞、提高性能等，`MySQL` 在设计的时候，每执行一次就进行提交。

所以在事务中，要谨慎使用会`隐式提交`的语句，否则可能得不到预期的效果。

### 2.3 自动提交

如果把 `AUTOCOMMIT` 设置为 `OFF`，那么之前的语句都会可以被理解成一个事务，需要每次显式的 `commit` 或 `rollback`，否则会一直阻塞。

举例：

* `session A`：

```sql
localhost@test > set autocommit = on;
Query OK, 0 rows affected (0.00 sec)

localhost@test > select @@autocommit;
+--------------+
| @@autocommit |
+--------------+
|            1 |
+--------------+
1 row in set (0.00 sec)

localhost@test > set autocommit = off;
Query OK, 0 rows affected (0.00 sec)

localhost@test > select @@autocommit;
+--------------+
| @@autocommit |
+--------------+
|            0 |
+--------------+
1 row in set (0.00 sec)
```

* `session B`：

```sql
localhost@test > set autocommit = on;
Query OK, 0 rows affected (0.00 sec)

localhost@test > select @@autocommit;
+--------------+
| @@autocommit |
+--------------+
|            1 |
+--------------+
1 row in set (0.00 sec)

select * from test_autocommit;
+-----------+-------+
| id        | count |
+-----------+-------+
| 100000000 |     4 |
+-----------+-------+
1 row in set (0.01 sec)
```

然后按照顺序，先后执行：

* `session A`：

```sql
localhost@test > select * from test_autocommit;
+-----------+-------+
| id        | count |
+-----------+-------+
| 100000000 |     4 |
+-----------+-------+
1 row in set (0.00 sec)

localhost@test > update test_autocommit set count = 0 where id = 100000000;
Query OK, 1 row affected (0.01 sec)
Rows matched: 1  Changed: 1  Warnings: 0

localhost@test > select * from test_autocommit;
+-----------+-------+
| id        | count |
+-----------+-------+
| 100000000 |     0 |
+-----------+-------+
1 row in set (0.00 sec)
```

* `session B`：

```sql
localhost@test > select * from test_autocommit;
+-----------+-------+
| id        | count |
+-----------+-------+
| 100000000 |     4 |
+-----------+-------+
1 row in set (0.00 sec)
```

也即，在 ``session B`` 中，还是原来的值 `4`。

换言之，因为 ``session A`` 的 `update` 语句还没被提交，所以值并没改变。

### 2.4 可能存在的问题

* 连接池的问题

假设框架里使用了 `连接池`，那么，就可能存在复用上次连接情况。

比如如上一个链接的 `autocommit` 是 `off`、事务没有 `commit` 等，如果这个连接仍然存在且被下一个请求复用，那么可能会导致各种奇怪的问题，如无法获取数据、不能成功写入等。

* 互相阻塞的问题

假设多个 `session` 同时 `set autocommit = off`，那么，这些 `session` 之间的调用，就可能互相阻塞（本质也即开启了两个事务，可参考事务阻塞的分析）。