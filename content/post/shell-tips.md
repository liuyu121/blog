---
title: "Shell Tips"
date: 2014-09-18T19:51:01+08:00
draft: false
categories: ["Shell"]
tags: ["Shell"]
typora-root-url: ../../static
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

## 字符串

### spli

* `tr`：先分割：

```shell
#!/usr/bin/env bash

IN="zhangsan@gmail;lisi@qq.com"

arr=$(echo $IN | tr ";" "\n")

for x in $arr
do
    echo "> [$x]"
done
```

* 借助系统输出分割符：`IFS`：默认为 "\n"，修改成 `;` 即可：

```shell
#!/usr/bin/env bash

IN="zhangsan@gmail;lisi@qq.com"

OIFS=$IFS
IFS=';'
arr2=$IN
for x in $arr2
do
    echo "> [$x]"
done

IFS=$OIFS
```

### substr

* `awk`：使用 `substr`(源字符串,开始索引,长度)  ，索引以 `0` 开始：

```shell
$ echo abcdefg | awk '{$a=substr($0,0,2);print $a;}'
ab
```

* `expr`：`expr substr` ，字符串 开始索引 长度 ，索引以 `1` 开始

```shell
$ expr substr "abcdefg" 1 2
ab
```

* `echo`：${str:开始索引} 或 echo ${str:开始索引:长度}  ，索引从 `0` 开始：

```shell
$ str=abcdefg;echo ${str:0:2}
ab
```

## awk

* 统计某一列值大于等于 `5000` 的总行数：

```shell
cat diamond.csv | grep -iv test |  awk -F ',' '{if($2>=5000)print }' | wc -l
```

## 进程

* 查看进程正在进行的工作：`pstack $PID`

* 查看进程端口的占用

```shell
# 如查看 mysql 进程的端口占用

ps aux | grep -i mysql
netstat -apn  | grep -i mysqld 
lsof -i:端口号
```

* `shel` 的多进程，如下所示，然后就可以读取了，不读取的话，会一直阻塞

```shell
mkfifo fifofile
echo data > fifofile
```

* 杀死僵尸进程

用 `ps + grep` 命令寻找僵尸进程：

```shell
ps -A -ostat,ppid,pid,cmd | grep -e '^[Zz]'
```
命令注解：

`-A`：参数列出所有进程

`-o`： 自定义输出字段 我们设定显示字段为 `stat`（状态）, `ppid`（进程父 `id`）,` pid` (进程 `id`)，`cmd`（命令）这四个参数

因为状态为  `z` 或 `Z` 的进程为僵尸进程，所以我们使用 `grep` 抓取 `stat` 状态为 `zZ` 进程，再 `kill -HUP $PID`，如果 `kill` 子进程的无效，可以尝试 `kill` 其父进程来解决。

## wget

* 整站下载：http://fosswire.com/post/2008/04/create-a-mirror-of-a-website-with-wget/

```shell
wget --convert-links --recursive -l inf -N -e robots=off -R -nc  --default-page=index.html -E -D$URL1,$URL2,$URL0 --page-requisites  -B$URL0 -X$URL1,$URL2 --cut-dirs=1 -I*/wp-content/uploads/*, -H -F $URL www.douban.com
```
* 断点续传

```shell
wget -r -P /download/location -A jpg,jpeg,gif,png http://www.site.here
```

## bash_profile、bashrc 区别

![](/img/profile-bashrc-diff.png)

