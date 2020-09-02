---
title: "Mysql Order by 问题"
date: 2018-08-06T17:49:41+08:00
draft: false
categories: ["MySQL"]
tags: ["MySQL","Database"]
---


环境说明

* MySQL 版本：`5.1.73-log`

* 存储引擎：` ENGINE=InnoDB `

## 问题起因

某个需求实现中，采用的是通过使用「业务表」的`某个时间字段` 作为 `游标`，通过每次获取的数量作为 `偏移量`，遍历一个 `静态数据的集合`，从而达到迭代遍历的目的。

也即，会构造 `<last_id|time>` 的游标，`time` 按照月划分（业务需要），从 `0` 开始计数。

* `time`： 表示起始时间，截止时间为 `+1 月`。

* `last_id`：表示当前该时间取到了哪里。

举例说明：

* `0|2018-01-01`：表示在 `[1月, 2月)` 从 `0` 开始获取 `n` 条数据

* `128|2018-01-01`：表示在 `[1月, 2月)` 从 `128` 开始获取 `n` 条数据

当数据集合为空时，`break` 至下一个月。

一切看起来正常，但在最终 `check` 数据的时候，却发现有 *`重复的推送`*。

下面，我们举个例子，尝试解释该问题。

### 场景还原

> 注：以下数据均为举例说明，不代表生产环境真实数据情况。

推送订单（`orders`），使用 `pay_time` 作为游标。

* `sql`：

``` sql
select * from orders where pay_time >= '2018-01-01 00:00:00' and pay_time <= '2018-01-31 23:59:59' order by pay_time asc limit 100, 500

```
我们设想这里在相同 `pay_time` 的上，会根据主键 `id` 进行 `asc`。

* 索引：

```sql
`KEY `pay_time` (`pay_time`),
```
* `explain`：

```sql
+----+-------------+--------------+-------+---------------+----------+---------+------+-------+-------------+
| id | select_type | table        | type  | possible_keys | key      | key_len | ref  | rows  | Extra       |
+----+-------------+--------------+-------+---------------+----------+---------+------+-------+-------------+
|  1 | SIMPLE      | orders | range | pay_time      | pay_time | 9       | NULL | 57420 | Using where |
+----+-------------+--------------+-------+---------------+----------+---------+------+-------+-------------+
```
按照预期，该 `sql` 理应能够不重复的遍历整个数据集合。但不幸的是，事实并没按预期发生，在推送过程中，出现了重复推送的问题。

### 举例说明

* `pay_time` 为 `2019-01-01 18:09:34`。

* 该时间点有 `2` 条数据，`id` 为 `100`，`98`。

* 某次 `limit 100, 500` 恰好取到了这个时间的 `1 条数据`，取出来的是 `id=98`，也即发生了 `跨页问题`。

* 下次偏移依然从这个时间开始，但 `MySQL` 仍然返回了 `id=98`，而不是另一条数据：`id=100`。

* 这里，并没有按照我们预想的一样，有个隐含的排序规则：`id asc`。

## 分析与解决

通过上面的描述，我们猜测 `MySQL` 针对 `order by ... limit ` 的查询，并没有对结果集进行排序。具体到这个例子，并没有按照 `id asc` 或 `id desc` 排序。而且很可能是 `随机` 返回。

去找 `mysql` 手册，`5.1 版本` 没找到，直接看 `5.7 版本`[^pa1]。 

这篇文章很明确给出了答案：

```
If multiple rows have identical values in the ORDER BY columns, the server is free to return those rows in any order, and may do so differently depending on the overall execution plan. In other words, the sort order of those rows is nondeterministic with respect to the nonordered columns.

```

通俗翻译过来就是：

```
如果 ORDER BY 的那个字段（列），在数据库里有多条数据（行），MySQL 会按照随机顺序返回查询结果，具体取决于对应的执行计划。

或者说，如果排序的列是无序的，那么排序的结果行的顺序也是 *非确定性的*。
```
而我们的查询场景，正好符合这个解释。

通过这篇文章，我们还可以了解到 `MySQL` 是到底是怎么解析 `order by ... limit` 语句的，比如如下一段：

```
If you combine LIMIT row_count with ORDER BY, MySQL stops sorting as soon as it has found the first row_count rows of the sorted result, rather than sorting the entire result. If ordering is done by using an index, this is very fast. If a filesort must be done, all rows that match the query without the LIMIT clause are selected, and most or all of them are sorted, before the first row_count are found. After the initial rows have been found, MySQL does not sort any remainder of the result set.

```

简而言之，`MySQL` 在按照 `ORDER BY` 排序后的匹配结果集，会且只会选取 `LIMIT row_count` 行返回，而不会再针对该结果集进行排序。


既然知道了原因，那么就很好解决了。既然没有按照设想的 `id asc`，那么就在 sql 指定顺序：

``` sql
select * from orders where pay_time >= '2018-01-01 00:00:00' and pay_time <= '2018-01-31 23:59:59' order by pay_time asc, id asc limit 100, 500

```
显式指明 `id asc`，明确告诉 `MySQL`，我们需要针对主键 id 进行一次排序。

但需要注意的是，这里只能选取具有 `unqiue 属性` 的字段，才能保证稳定排序。（思考下是为什么）。

## 延伸

在实际的业务场景中，即便我们使用了 `order by pay_time asc, id asc`，但还是可能存在问题。

一个典型的场景如下：

* 假设脚本执行到了 `当前时间`（设为 `etime`）停止，取到了 n 条数据，假设 `id=100`。

* 恰好这时有 `id=98` 的订单在变更状态，但并没有被这次 `轮询` 获取到。

* 下次脚本启动时，从上次的时间 `etime` 开始，如果是使用了 `id asc`，会导致 `id=98`的数据被忽略，重复取到了 `id=100` 这条。如果是使用了 `id > last_id` 的条件，会导致漏掉了 `id=98` 的数据。

当然，这个问题就和 `MySQL` 无关了，主要是业务理解不当导致的。

也即，因为 `并发` 导致遍历的不是一个 `静态数据集合`。这里，我们需要通过别的手段进行解决。

最简单粗暴的解决方案为，加一个 `时间戳限制`：

``` sql
select * from orders where pay_time >= '{$stime}' and pay_time <= '{$etime} and pay_time <= '{30秒之前}' order by pay_time asc, id asc limit 100, 500

```

也即，`在已经过去的时间里，业务终态的数据集合必然是静态的`。


[^pa1]: [8.2.1.17 LIMIT Query Optimization](https://dev.mysql.com/doc/refman/5.7/en/limit-optimization.html)
