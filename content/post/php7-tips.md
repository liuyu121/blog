---
title: "PHP7 初识"
date: 2018-07-06T19:39:56+08:00
draft: false
categories: ["PHP"]
tags: ["php"]
---


> 注：以下部分内容摘自 《PHP7 内核剖析》

## 与之前版本的区别

`php7` 相较于 `php 5.x`，号称性能得到了极大提升，从版本上看确实如此 :) 。那么，到底是哪些地方改变了呢。

* 抽象语法树

在之前的版本，`PHP` 代码在语法解析阶段直接生成了 `Zend VM` 指令，也就是在 `zend_languange_parser.y` 中直接生成 `opline` 指令，这使得`编译器`与`执行器`耦合在了一起。

编译生成的指令供`执行引擎`使用，该指令是在`语法解析`时直接生成的，假如要把`执行引擎`换成别的，就需要修改 `语法解析规则`；或者如果 `PHP` 的语法规则变了，但对应的执行指令没有变化，那么也需要修改语法解析规则。

`PHP7` 中新增了`抽象语法树`，首先将 `PHP` 代码解析生成`抽象语法树`，然后将`抽象语法树`编译成 `Zend VM` 指令。`抽象语法树`的加入，使得 `PHP` 的`编译器`与`执行器`很好地隔离，`编译器`不需要关心指令的生成规则，`执行器`根可以根据自己的规则将`抽象语法树`编译成对应的指令，`执行器`同样不需要关心该指令的语法规则是什么样的。

* `Native TLS`

`PHP 5.x` 提供的`线程安全资源管理器`，将全局资源进行了`线程隔离`，不同的线程之间互不干扰。使用全局的资源需要先获取本线程的资源池，这是个耗时的过程，因此 `PHP 5.x` 通过`参数传递`的方式降本线程的资源池传递给其他函数，避免重复查找。这种方式使得几乎所有的函数都需要加上`接收资源池的参数`，然后调用其他函数时，再把这个参数传递进去，容易遗漏，且不优雅。

`PHP7` 中使用 `Naitve TLS`(线程局部存储)来保护线程的资源池，简单地讲就是通过 `_thread` 标志一个`全局变量`，这样这个`全局变量`就不是线程独享的了，不同线程的修改不会互相影响。

* 指定函数参数、返回值类型

```php
// 参数必须为字符串，返回值必须是数组，否则会 error
function foo(string $name) : array {
	return [];
}
```
* `zval` 结构的变化 ---> 重点

`zval` 是 `PHP` 中很重要的结构，因为 `PHP` 动态、弱类型的特性，所以该结构是应用最普遍的结构之一。

> `PHP 5.	x`：

```c
struct _zval_struct {
	/* Variable information */
	zvalue_value value;  /* value 是个 union 结构体 用来适配不同的变量类型 */
	zend_unit refcount__gc; /* 引用计数器 */
	zend_uchar type; /* active type 也即值类型 	*/
	zend_uchar is_ref__gc; /* 表明该变量是否是地址引用 */ 
};

typedef union _zvalue_value {
	/* 不同精度的长整型 */
	long lval; // long value
	double dval; // double value
	
	struct {
		char *val;
		int len;
	} str;
	
	HashTable *ht; // hash table 类型的值
	
	zend_object_value obj;
	zend_ast *ast;
} zvalue_value; 

```
其中，比较重要的是 `refcount__gc`，记录了变量的引用计数。引用计数是实现`变量自动回收`的基础，也就是`记录一个变量有多少个地方在使用`的一种机制。

`PHP 5.x` 的引用计数器是在 `zval` 中而不是在具体的 `value` 中，这样会导致`变量复制`时候，需要两个结构，也即，`zval`、`zvalue_value` 始终绑定在一起。

`PHP7` 将就引用计数器转移到了具体的 `value` 中。因为 `zval` 只是变量的`载体`，可以简单地认为是变量名，而 `value` 才是真正的值。这个改变使得 `PHP 变量` 之间的`复制、传递`更加简洁、易懂。除此之外，`zval` 结构的大小也从 `24 byte` 减少到 `16 byte`。这种结构体占用的减少，也是 `PHP7` 能够降低系统资源占用一个优化点所在。

* 异常处理

`PHP 5.x` 很多操作会直接抛出 `error`，`PHP7` 则是将多数错误以 `异常`形式抛出，这样就可以使用 `try-catch` 进行捕捉。如：

```php
<?php
try {
    test(); // 不存在的函数
} catch (Throwable $e) {
    echo "Catch exception: " . $e->getMessage() . PHP_EOL;
}	
```
* `HashTable` 的变化

`HashTable` 在 `PHP` 的内部实现里，使用非常频繁。如实现强大的 `array()`、`函数符号表`、`类符号表`、`常量符号表`等。

`PHP7` 优化了 `HashTable` 的结构，使其大小从 `72 byte` 减小至 `32 byte`。

* 执行器

`execute_data`、`opline` 采用寄存器变量存储，执行器的调度函数为 `execute_ex()`。这个函数负责执行 `PHP` 代码编译生成的 `Zend VM` 指令。在执行期间会频繁用到上述两个变量。

在 `PHP 5.x` 中，这两个变量是由 `execute_ex()` 通过参数传递给各指令 `handler` 的。

在 `PHP7` 中，不再采用参数传递方式，而是将 `execute_data`、`opline` 通过寄存器进行存储，避免了传参导致的频繁`出入栈操作`。同时，寄存器相比内存的访问速度更快。

这个优化使得 `PHP7` 的性能有了 `5%` 左右的提升。

* 新的参数解析方式

`PHP 5.x` 通过 `zend_parse_parameters()` 解析函数的参数，`PHP7` 提供了另一种方式（更快的解析参数），且保留了原方式。

