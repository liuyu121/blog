---
title: "Shell Tips"
date: 2014-09-18T19:51:01+08:00
draft: false
categories: ["Shell"]
tags: ["shell"]
---


一些常用的 `shell` 技巧分享，很多都可以举一反三的扩展 ：）

## 文本处理

* 逐行处理文本：这里不能用 `for`，空格会被分割，所以应该用 `read`

```shell
while read i;do echo "<p>$i</p>";done < test.txt
```

* 链接一行：可用于将一些文本格式化成 `php` 的数组格式等

```shell
cat test.txt | xargs | sed 's/ /","/g'
```

* 统计文本各行出现次数

```shell
cat test2.log | sort | uniq -c | sort -nrk1
```

* 两个文件的差集

```
# 想想为什么可以这么写
cat t1 t1 t2 | sort | uniq -u
```

* 去掉行尾的逗号

```shell
sed 's/[,]*$//g' test.txt
```

* 查找文件

```shell
# 如查找普通文件
find ./ -type f

# 查找.zip文件
find ./ -name '*.zip'

# 查找目标文件并修改权限 后面的\;必须的，表示按行输出 {} 表示找到的文件路径
find . -type f -exec chmod 644 {} \; 
```

* 删除 `utf8` 的 `bomb` 头

```shell
# 查找 bomd 头
grep -R $'\xEF\xBB\xBF' ./*
grep -r -I -l $'^\xEF\xBB\xBF' ./*

# 可使用 vim 替换
vim set nobomb
```


## awk

* 统计某一列值大于等于 `5000` 的总行数：

```shell
cat diamond.csv | grep -iv momo |  awk -F ',' '{if($2>=5000)print }' | wc -l
```

## 进程

* 查看进程端口的占用

```shell
# 如查看 mysql 进程的端口占用

ps aux | grep -i mysql
netstat -apn  | grep -i mysqld 
lsof -i:端口号
```
