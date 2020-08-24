---
title: "go for-range 问题"
date: 2020-08-18T17:45:22+08:00
lastmod: 2020-08-18T17:45:22+08:00
draft: false
categories: ["go"]
tags: ["go"]
typora-root-url: ../../static
---

先开宗明义吧，`for-range` 是个语法糖，内部还是以 `for 循环` 实现：

```go
for_temp := range
len_temp := len(for_temp)
for index_temp = 0; index_temp < len_temp; index_temp++ {
	value_temp = for_temp[index_temp]
	index = index_temp
	value = value_temp
	original body
}
```

这里，可以注意到，在 `for 循环` 之前：

* 定义了 `index`、`value` 两个全局变量。
* 做了一次拷贝，`for 循环` 的对象是该份拷贝。
* 获取了循环对象的长度

然后在 `for` 循环具体执行时，本质是遍历拷贝，然后每次遍历放入 `index` 与 `value` 变量，再执行 `original body`（`php` 的 `foreach` 也是）。所以，在使用 `for-range` 时，如果是一个很大的数组，会发生一次拷贝，比较浪费内存且耗时的，可以考虑使用切片代替（`arr[:]`），或者直接地址引用  `&arr` 。

结合上面的结论，来看看以下的例子。

* 迭代时，`index` 与 `value` 的地址是不变的：

```go
func testAddress() {
	// 迭代时，`index` 与 `value` 的地址是不变的
	nums := []int{10, 20, 30, 40}
	for index, value := range nums {
		fmt.Printf("Index: %d Value: %d Value-Addr: %X ElemAddr: %X \n", index, value, &value, &nums[index])
	}
}
```
输出：

```
Index: 0 Value: 10 Value-Addr: C0000B4008 ElemAddr: C0000B8000
Index: 1 Value: 20 Value-Addr: C0000B4008 ElemAddr: C0000B8008
Index: 2 Value: 30 Value-Addr: C0000B4008 ElemAddr: C0000B8010
Index: 3 Value: 40 Value-Addr: C0000B4008 ElemAddr: C0000B8018
```

* 循环时 `append`，不会死循环：

```go
func testAppend() {
	// 不会死循环
	v := []int{1, 2, 3}
	for i := range v {
		fmt.Println("i :", i)
		v = append(v, i)
	}

	// 这里能全部打印出来
	fmt.Println(v)
}
```

输出：

```
i : 0
i : 1
i : 2
[1 2 3 0 1 2]
```

* 结构体被修改

```go
type T struct {
	k string
}

func testStruct() {
	fmt.Println("-------- 不会修改值 --------")
	var arr [5]T
	for _, e := range arr {
		e.k = "xxx"
	}

	for _, e := range arr {
		fmt.Println(e.k)
	}

	fmt.Println("-------- 修改值 --------")

	var arr2 [5]T
	for i, _ := range arr2 {
		arr2[i].k = "foo"
	}

	for _, e := range arr2 {
		fmt.Println(e.k)
	}
}
```

输出：

```
-------- 不会修改值 --------





-------- 修改值 --------
foo
foo
foo
foo
foo
```

* 再看一个 `struct` 的例子

```go
func testStruct2() {
	arr := []T{
		T{"a"},
		T{"b"},
		T{"c"},
	}
	fmt.Println(arr)

	for i, t := range arr {
		fmt.Println(i, t.k)
		t.k = "1"
		fmt.Println(i, t.k)
	}

	fmt.Println(arr)
}
```
输出：

```
[{a} {b} {c}]
0 a
0 1
1 b
1 1
2 c
2 1
[{a} {b} {c}]
```
* 再看一个 `map`，随机输出

```go
func testMap() {
	slice := []int{0, 1, 2, 3}
	dict := make(map[int]*int)
	for index, value := range slice {
		fmt.Println(&index, &value)
		// 这里，本质指向的都是同一个地址，也即 &value
		dict[index] = &value
	}

	fmt.Println("-------- map --------")
	for k, v := range dict {
		fmt.Printf("%d => %d\n", k, *v)
	}
}
```

输出：

```
0xc00001a0a0 0xc00001a0a8
0xc00001a0a0 0xc00001a0a8
0xc00001a0a0 0xc00001a0a8
0xc00001a0a0 0xc00001a0a8
-------- map --------
0 => 3
1 => 3
2 => 3
3 => 3
```