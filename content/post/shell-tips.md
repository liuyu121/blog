---
title: "Shell Tips"
date: 2014-09-18T19:51:01+08:00
draft: false
categories: ["Shell"]
tags: ["shell"]
---


一些常用的 `shell` 技巧分享，很多都可以举一反三的扩展 ：）

-------------------------------

* 逐行处理文本

```
while read i;do echo "<p>$i</p>";done < test.txt

```

* 链接一行：可用于将一些文本格式化成 `php` 的数组格式等

```
cat test.txt | xargs | sed 's/ /","/g'

```

* 统计文本各行出现次数

```
cat test2.log | sort | uniq -c | sort -nrk1

```

* 两个文件的差集

```
# 想想为什么可以这么写
cat t1 t1 t2 | sort | uniq -u

```

* 去掉行尾的逗号

```
sed 's/[,]*$//g' test.txt

```

* 查看进程端口的占用

```
# 如查看 mysql 进程的端口占用

ps aux | grep -i mysql
netstat -apn  | grep -i mysqld 
lsof -i:端口号

```

* 查找文件

```
# 如查找普通文件
find ./ -type f

# 查找.zip文件
find ./ -name '*.zip'

# 查找目标文件并修改权限 后面的\;必须的，表示按行输出 {} 表示找到的文件路径
find . -type f -exec chmod 644 {} \; 

```

* 删除 `utf8` 的 `bomb` 头

```
# 查找 bomd 头
grep -R $'\xEF\xBB\xBF' ./*
grep -r -I -l $'^\xEF\xBB\xBF' ./*

# 可使用 vim 替换
vim set nobomb

```
