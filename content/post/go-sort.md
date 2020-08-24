---
title: "Go Sort 使用"
date: 2020-08-24T21:30:23+08:00
lastmod: 2020-08-24T21:30:23+08:00
draft: false
categories: ["go"]
tags: ["go"]
typora-root-url: ../../static
---





## 排序 slice、map 等

一般排序使用 `sort` 包，下面以 `int` 型举例。

* 排序 `int slice`

```go
func sortSlice() {
	fmt.Println("----- 一维正序排序 -----")
	nums := []int{9, 8, 0, 1, 7, 8, 100, -1, 0}
	fmt.Println("before : ", nums)
	sort.Ints(nums)
	fmt.Println("after : ", nums)

	fmt.Println("----- 一维逆序排序 -----")
	nums = []int{9, 8, 0, 1, 7, 8, 100, -1, 0}
	sort.Sort(sort.Reverse(sort.IntSlice(nums)))
	fmt.Println("After reversed: ", nums)

	fmt.Println("----- 多维数组，按照 index=0 排序 -----")
	nums2 := [][]int{{9, 10}, {1, 4}, {3, 6}, {8, 12}}
	fmt.Println("before : ", nums2)

	sort.Slice(nums2, func(i, j int) bool {
		return nums2[i][0] < nums2[j][0]
	})
	fmt.Println("after : ", nums2)
}
```

输出：

```
----- 一维正序排序 -----
before :  [9 8 0 1 7 8 100 -1 0]
after :  [-1 0 0 1 7 8 8 9 100]
----- 一维逆序排序 -----
After reversed:  [100 9 8 8 7 1 0 0 -1]
----- 多维数组，按照 index=0 排序 -----
before :  [[9 10] [1 4] [3 6] [8 12]]
after :  [[1 4] [3 6] [8 12] [9 10]]
```
*  排序 `int map`  --  按 `key`

```go
// 按照 key 排序输出 map
func sortMapKey() {
	fmt.Println("map 排序：按照 key 从小到大输出")
	dict := map[int]int{
		1:  123,
		3:  10123,
		17: 109,
		7:  1,
	}
	fmt.Println(dict)

	var keys []int
	for k, _ := range dict {
		keys = append(keys, k)
	}

	// 先按照 key 排序
	sort.Ints(keys)
	fmt.Println(keys)

	// 按照顺序输出
	for _, v := range keys {
		fmt.Printf("k : %v, v : %v\n", v, dict[v])
	}
}
```

输出：

```
map 排序：按照 key 从小到大输出
map[1:123 3:10123 7:1 17:109]
[1 3 7 17]
k : 1, v : 123
k : 3, v : 10123
k : 7, v : 1
k : 17, v : 109
```

*  排序 `int map`  --  按 `value`：这里，会麻烦很多，这时就体现出 `go` 真的是。。。

```go
// 按照 value 排序输出 map
// --- 需要借助 sort 包，实现该接口
type KV struct {
	k int
	v int
}

type KVS []KV

func (kvs KVS) Len() int {
	return len(kvs)
}

func (kvs KVS) Less(i, j int) bool {
	return kvs[i].v < kvs[j].v
}

func (kvs KVS) Swap(i, j int) {
	kvs[i], kvs[j] = kvs[j], kvs[i]
}

func sortMapValue() {
	fmt.Println("map 排序：需要构建 struct，再使用 sort 包来进行排序，需要实现 sort")
	dict := map[int]int{
		1:  123,
		3:  10123,
		17: 109,
		7:  1,
	}
	fmt.Println(dict)

	kvs := make(KVS, len(dict))
	i := 0
	for k, v := range dict {
		kvs[i] = KV{k, v}
		i++
	}
	fmt.Println(kvs)
	sort.Sort(kvs)
	fmt.Println(kvs)
}
```

输出：

```
map 排序：需要构建 struct，再使用 sort 包来进行排序，需要实现 sort
map[1:123 3:10123 7:1 17:109]
[{1 123} {3 10123} {17 109} {7 1}]
[{7 1} {17 109} {1 123} {3 10123}]
```