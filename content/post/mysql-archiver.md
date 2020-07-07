---
title: "Mysql 归档"
date: 2018-07-16T19:32:32+08:00
draft: false
categories: ["MySQL"]
tags: ["mysql","database"]
---


## 归档方案

### pt-archiver

使用 `pt-archiver` 归档数据。

> [官方文档](https://www。percona。com/doc/percona-toolkit/3。0/pt-archiver。html)

### mysql 分区

`mysql` 官方提供的分区方案。

> [mysql 分区](http://mysql。taobao。org/monthly/2017/11/09/)

## 手动归档

场景：某业务单表几 kw，需要归档，一般地，以记录生成时间归档（`time`）。

* 方案1：复制表

复制表，按照条件插入数据（此种方法除了主键索引不包括其他索引）：

```sql
CREATE TABLE table_new as select * from table_old  where time < “2018-01-01 00:00:00";  
ALTER TABLE table_new change id id int primary key auto_increment;  
```

* 方案2

创建一张空表，结构和索引和原表一样，再插入数据：

```sql
CREATE TABLE table_new like table_old; 
INSERT INTO table_new select * from table_old  where time < "2018-01-01 00:00:00”;
```
* 总结

以上两种方案，都需要清理原表：

```sql
DELETE FROM table_old where time < '2018-01-01 00:00:00';
```

新表可能存在各种空洞，需要优化表，整理表碎片（这里就不平滑了）：

```sql
show OPEN TABLES where In_use > 0; # 查看当前被锁的表
```

查看表的碎片：

```sql
show table status like 'table_old’\G
```

获取表的碎片：

```sql
SELECT t。TABLE_SCHEMA, t。TABLE_NAME, t。TABLE_ROWS, t。DATA_LENGTH, t。INDEX_LENGTH,  concat(round(t。DATA_FREE / 1024 / 1024, 2), 'M') AS data_free FROM information_schema。tables t where t,TABLE_NAME = 'trade_old’;
```

* 碎片产生的原因

> 官方解释：

```
In the InnoDB multi-versioning scheme, a row is not physically removed from the database immediately when you delete it with an SQL statement.

InnoDB only physically removes the corresponding row and its index records when it discards the update undo log record written for the deletion.

This removal operation is called a purge, and it is quite fast, usually taking the same order of time as the SQL statement that did the deletion.
```

在 `InnoDB` 中，删除一些行，这些行只是被标记为 `已删除`，而不是真的从索引中物理删除了，因而空间也没有真的被释放回收。

`InnoDB` 的 `Purge 线程` 会异步的来清理这些没用的索引键和行。但是依然没有把这些释放出来的空间还给操作系统重新使用，因而会导致页面中存在很多空洞。

如果表结构中包含动态长度字段，那么这些空洞甚至可能不能被 `InnoDB` 重新用来存新的行，因为空间空间长度不足。可参考 [Overview of fragmented MySQL InnoDB tables](https://lefred。be/content/overview-of-fragmented-mysql-innodb-tables/)。

另外，删除数据就会导致页（`page`）中出现空白空间，大量随机的 `DELETE` 操作，必然会在数据文件中造成不连续的空白空间。而当插入数据时，这些空白空间则会被利用起来，于是造成了数据的存储位置不连续。

物理存储顺序与逻辑上的排序顺序不同，这种就是数据碎片。

对于大量的 `UPDATE`，也会产生文件碎片，`Innodb` 的最小物理存储分配单位是页(`page`)，而 `UPDATE` 也可能导致页分裂（`page split`），频繁的页分裂，页会变得稀疏，并且被不规则的填充，所以最终数据会有碎片。

* `OPTIMIZE TABLE`

使用 `OPTIMIZE TABLE` 会重组表和索引的物理存储，减少对存储空间使用和提升访问表时的 `IO效率`。

> 注：对每个表所做的确切更改取决于该表使用的存储引擎（`INNODB,MYISAM, ARCHIVE，NDB`）。
 
`OPTIMIZE TABLE` 会重组表数据和索引的物理页，对于减少所占空间和在访问表时优化`IO` 有效果。

`OPTIMIZE` 操作会暂时锁住表，而且数据量越大，耗费的时间也越长。

* 另一种 `OPTIMIZE` 方案

```sql
ALTER TABLE table_name ENGINE = Innodb;
```

这其实是一个 `NULL` 操作，表面上看什么也不做，实际上重新整理了碎片。

当执行优化操作时，实际执行的是一个空的 `ALTER` 命令，但是这个命令也会起到优化的作用，它会重建整个表，删掉未使用的空白空间。

### 一些资料

* [Overview of fragmented MySQL InnoDB tables](https://lefred。be/content/overview-of-fragmented-mysql-innodb-tables/)

* [Innodb 可视化工具](https://github。com/jeremycole/innodb_ruby/)

* [sysbench](https://github.com/akopytov/sysbench)：使用 `sysbench ` 生成测试数据、压测等

* [淘宝数据库内核月报](http://mysql.taobao.org/monthly/)
