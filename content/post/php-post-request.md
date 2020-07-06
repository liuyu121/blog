---
title: "PHP 处理 POST 请求"
date: 2015-03-12T19:49:28+08:00
draft: false
categories: ["PHP"]
tags: ["php"]
---


## 默认的处理方式

我们知道，在 `php` 下获取 `POST 数据`极其简单，只需要使用 `$_POST` 的全局数组即可。

> 题外话：这种使用简单操作方便的特性，也是为什么 `php` 如此流行的关键原因之一。 php 是世上最好的语言。 ：）

但有个疑问，`$_POST` 是处理哪些 `Content-type` 的请求呢。

通过查看 `php manual`：

```
当 HTTP POST 请求的 Content-Type 是 application/x-www-form-urlencoded 或 multipart/form-data 时，会将变量以关联数组形式传入当前脚本。
```

下面我们使用 `curl` 来验证下。

* 测试代码

```php
<?php

var_dump($_POST);
```

* 测试 application/x-www-form-urlencoded

```shell
curl -v -H 'Content-type: application/x-www-form-urlencoded' -d 'name=liuduoyu'  http://127.0.0.1/
*   Trying 127.0.0.1...
* TCP_NODELAY set
* Connected to 127.0.0.1 (127.0.0.1) port 80 (#0)
> POST / HTTP/1.1
> Host: 127.0.0.1
> User-Agent: curl/7.63.0
> Accept: */*
> Content-type: application/x-www-form-urlencoded
> Content-Length: 13
>
* upload completely sent off: 13 out of 13 bytes
< HTTP/1.1 200 OK
< Server: nginx/1.8.1
< Date: Fri, 12 Jul 2019 03:13:03 GMT
< Content-Type: text/html
< Transfer-Encoding: chunked
< Connection: keep-alive
< X-Powered-By: PHP/5.3.29
<
array(1) {
  ["name"]=>
  string(8) "liuduoyu"
}
* Connection #0 to host 127.0.0.1 left intact

```
* 测试 multipart/form-data

```shell
curl -v -H 'Content-type: multipart/form-data'   -F 'data={"score":"129"}&name=liuduoyu'   http://127.0.0.1/
*   Trying 127.0.0.1...
* TCP_NODELAY set
* Connected to 127.0.0.1 (127.0.0.1) port 80 (#0)
> POST / HTTP/1.1
> Host: 127.0.0.1
> User-Agent: curl/7.63.0
> Accept: */*
> Content-Length: 168
> Content-Type: multipart/form-data; boundary=------------------------2d07b2e8fe03448d
>
< HTTP/1.1 200 OK
< Server: nginx/1.8.1
< Date: Fri, 12 Jul 2019 03:13:38 GMT
< Content-Type: text/html
< Transfer-Encoding: chunked
< Connection: keep-alive
< X-Powered-By: PHP/5.3.29
<
array(1) {
  ["data"]=>
  string(29) "{"score":"129"}&name=liuduoyu"
}
* Connection #0 to host 127.0.0.1 left intact

```
## 处理其他 Content-Type

很多时候，当我们与外部系统交互时，在调试过程中，往往会遇到各自无法获取对方数据的问题。

典型的如：

* `java` 很多框架的 `HttpClient` 常用的 `Content-Type: application/json`
	
* `微信开发`中，获取推送的报文数据

所以，我们需要使用 `php://input` 来获取数据。

* 测试代码

```php
$s = file_get_contents("php://input");
var_dump($s);

```

* Content-Type: application/json'

```shell
curl -v -H 'Content-type: application/json'  -d '{"name": "liudoyu"}' http://127.0.0.1/
*   Trying 127.0.0.1...
* TCP_NODELAY set
* Connected to 127.0.0.1 (127.0.0.1) port 80 (#0)
> POST / HTTP/1.1
> Host: 127.0.0.1
> User-Agent: curl/7.63.0
> Accept: */*
> Content-type: application/json
> Content-Length: 19
>
* upload completely sent off: 19 out of 19 bytes
< HTTP/1.1 200 OK
< Server: nginx/1.8.1
< Date: Fri, 12 Jul 2019 03:52:44 GMT
< Content-Type: text/html
< Transfer-Encoding: chunked
< Connection: keep-alive
< X-Powered-By: PHP/5.3.29
<
string(19) "{"name": "liudoyu"}"
* Connection #0 to host 127.0.0.1 left intact

```

## php-curl 指定 Content-Type

下面是 php curl 扩展常用的 `Content-Type`：

* 文件

```php
curl_setopt($ch, CURLOPT_HTTPHEADER, array(
		'Content-Type: multipart/form-data;charset=UTF-8',
	)
);
```

* json

```php
curl_setopt($ch, CURLOPT_HTTPHEADER, array(
		'Content-Type: application/json',
	)
);
```