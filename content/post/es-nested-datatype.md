---
title: "Es Nested 类型"
date: 2020-07-09T15:36:15+08:00
lastmod: 2020-07-09T15:36:15+08:00
draft: false
categories: ["Es"]
tags: ["es"]
---

有个服务写 `es`，遇到了以下报错：

```
Failed to execute bulk item (index) BulkShardRequest

...

limit of total fields [1000] in index
```

使用的 `es`版本为`5.3.2`，在 `es` 的数据项中，使用了 `nested` 类型，字面意思是这个 `index` 下的 `fileds` 超过了 `1000`，禁止写入了。

问题原因很简单，但其中涉及到 `es` 的 `objects`  、`nested`类型，下面我们来具体分析下这俩类型的异同。

## object 类型

### 例子 1

我们先看个 `object` 类型的例子，下面这个文档是一篇文章的评论信息，包含了 `3` 条 `comment`，且该 `comment` 为 `object` 类型：

```json
PUT my_index/my_type/1
{
  "title": "test",
  "body": "这是一个测试文档",
  "tags": ["test", "xxx"],
  "published_on": "2020-07-09",
  "comments": [
    {
      "name": "zhangsan",
      "age": 24,
      "comment": "👍 写得真好",
      "commented_on": "2020-07-09"
    },
    {
      "name": "lisi",
      "age": 20,
      "comment": "多谢，学习了",
      "commented_on": "2020-07-09"
    },
    {
      "name": "wangwu",
      "age": 33,
      "comment": "涨姿势",
      "commented_on": "2020-07-09"
    }
  ]
}
```

写入 `es` 后，我们来查询 `name = wangwu` 的评论，分别测试 `age = 10、20、33` 等 `case`，查询语法如下，修改 `age` 为对应的值即可（用 `kibana` 语法表示更简明）：

```json
GET /my_index/_search?pretty
{
  "query": {
    "bool": {
      "must": [
        {
          "match": {
            "comments.name": "wangwu"
          }
        },
        {
          "match": {
            "comments.age": 10
          }
        }
      ]
    }
  }
}
```

测试结果如下：

* 1> `comments.name: "wangwu" && comments.age: 10`：返回空
* 2> `comments.name: "wangwu" && comments.age: 20`：返回 `_id=1`的文档（也即我们刚写入的那条数据）
* 3> `comments.name: "wangwu" && comments.age: 33`：返回 `_id=1`的文档

从上面的现象可知，其实 `3>` 条结果才是我们的预期，而 `2>` 这个 `case`，虽然并不存在 `name = wangwu AND age = 20` 的情况，但也返回了。

这是为什么呢，下面来一探究竟。

### 分析

在 `es`中， `object fields` [^pa1] 支持 `json` 格式的文档存储，也即支持多层嵌套，然后可以对其进行嵌套搜索，如上面例子所见：`comments.name: "wangwu"`。

但在其在内部实际存储该类型时，会被展开成扁平化的  `key-value pairs`  ，其中 `value` 是同一个 `key` 的聚合，也即，上面的实例中，最后被格式化为了如下格式：

```json
{
  "comments.name": ["zhangsan", "lisi", "wangwu"],
  "comments.age":  [24, 20, 33],
}
```

一眼便知，为什么会出现上面例子中 `2>` 这个 `case`，因为 `comments.age` 这个 `key` 的 `multi-value`里，有 `20` 这个值，所以便被匹配出来。

问题来了，我们就是精确匹配呢，使用 `nested` 类型可解决。

## nested 类型

`Nested fileds`[^pa2] 看起来和 `object fields` 类似，都支持多层嵌套查询，但实际上，它的内部存储方式却不一样。

### 例子 2

我们新建个 `coments` 类型为 `nested` 的 `index`：

```json
PUT my_index3
{
  "mappings": {
    "my_type": {
      "properties": {
        "comments": {
          "type": "nested" 
        }
      }
    }
  }
}
```

然后插入 `例子 1` 中的测试数据，同样的做相关测试，具体过程就省略了，注意，查询语法的区别[^pa3]：

```json
GET my_index3/_search
{
  "query": {
    "nested": {
      "path": "comments",
      "query": {
        "bool": {
          "must": [
            { "match": { "comments.name": "wangwu" }},
            { "match": { "comments.age":  33 }} 
          ]
        }
      }
    }
  }
}
```

测试结果如下（`kibana` 不支持这种查询语法，下面的搜索条件只是沿用上面例子的，为了方便查看）：

* 1> `comments.name: "wangwu" && comments.age: 10`：返回空
* 2> `comments.name: "wangwu" && comments.age: 20`：返回空
* 3> `comments.name: "wangwu" && comments.age: 33`：返回 `_id=1`的文档

我们发现，这种搜索结果才是预期的。

### 分析

`nested fileds` 内部实现方式与 `object` 不同之处在于：

* `object`：在内部，会被展开成扁平化的  `key-value pairs`

```json
Internally, this document is indexed as a simple, flat list of key-value pairs.
```

* `nested`：在内部，会索引数组中的每个对象作为单独的隐藏文档，这意味着每个嵌套对象可以独立于其他对象查询。

```json
Internally, nested objects index each object in the array as a separate hidden document, meaning that each nested object can be queried independently of the others.
```



## 问题解决

以上，我们知道 `object` 与 `nested` 这俩者的区别，接下来，下面回到开头的问题。

在实际的 `es` 使用中，我们是按天 `shard`，且有几个字段为 `nested` 类型, 根据  `dynamic mapping`  策略，`nested` 类型的 `key` 会被解析成 `fileds`，而业务有个场景是以 `随机值` 作为 `key` 写入 `es`，就导致了 `fileds` 快速膨胀，达到了 `1000` 的限制。

那为什么会限制在 `1000` 呢，因为如果不限制，`mapping` 快速膨胀后，会引起索引和副本数据膨胀，从而导致性能退化、内存问题等[^pa4]。

当然，这个限制也可以人为修改：

```json
PUT /my_index3/_settings 
{
  "index.mapping.total_fields.limit": 1111
}

GET /my_index3/_settings/index.mapping.total_fields.limit

{
  "my_index3" : {
    "settings" : {
      "index" : {
        "mapping" : {
          "total_fields" : {
            "limit" : "1111"
          }
        }
      }
    }
  }
}
```



需要注意的是，`dynamic mapping`  时，会以先写入的 `filed` 的数据格式作为当天的数据格式，后续写入不能修改，在弱类型语言中，比如 `php` 也即一旦创建完成，就不允许修改，否则会写入失败：

* 后续继续写入已有的数据，数据格式必须一致，因为此时 `field datatype 已经建立好了；
* 后续继续写入新增的 `field`，是可以成功写入的。

[^pa1]: [Object datatype](https://www.elastic.co/guide/en/elasticsearch/reference/5.3/object.html#object)
[^pa2]: [Nested datatype](https://www.elastic.co/guide/en/elasticsearch/reference/5.3/nested.html)
[^pa3]: [Nested query](https://www.elastic.co/guide/en/elasticsearch/reference/5.3/query-dsl-nested-query.html)
[^pa4]:[mapping-limit-settings](https://www.elastic.co/guide/en/elasticsearch/reference/master/mapping.html#mapping-limit-settings)