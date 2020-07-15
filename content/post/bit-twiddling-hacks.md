---
title: "Bit Twiddling Hacks"
date: 2020-07-14T19:29:40+08:00
lastmod: 2020-07-14T19:29:40+08:00
draft: false
categories: ["Linux"]
tags: ["linux"]

---



算法里面有很多 `位操作`，看 `redis` 源码，看到 `src/dict.c`  下一个函数：

```c
/* Function to reverse bits. Algorithm from:
 * http://graphics.stanford.edu/~seander/bithacks.html#ReverseParallel */
static unsigned long rev(unsigned long v) {
    unsigned long s = CHAR_BIT * sizeof(v); // bit size; must be power of 2
    unsigned long mask = ~0UL;
    while ((s >>= 1) > 0) {
        mask ^= (mask << s);
        v = ((v >> s) & mask) | ((v << s) & ~mask);
    }
    return v;
}
```

该函数主要作用是反转一个数字的所有位，觉得很巧妙（`centos` 下头文件位置：`/usr/include/`）。

在一些算法实现中，如：

* 偶数：`v & 1 == 0`
* 奇数：`v & 1 != 0`

在很多开源软件的代码里（如 `redis`），可见大量的位操作，这是因为在计算机世界里，本质就是一个个位操作（`0 or 1`），所以无疑是最快的。

这篇文章列举了大量的位操作，堪称奇技淫巧大集合，而位操作的难点是不好理解，看到已经有国人翻译成了中文了，厉害~



* 一些常用的十六进制

```python
>>> bin(0x55555555)
'0b 01010101 01010101 01010101 01010101'

>>> (0x55555555).bit_length()
31
```

* [Bit Twiddling Hacks](http://graphics.stanford.edu/~seander/bithacks.html)
* [【译】位运算的奇技淫巧：Bit Twiddling Hacks](https://blog.hufeifei.cn/2017/07/30/DataStructure/位运算的奇技淫巧/)