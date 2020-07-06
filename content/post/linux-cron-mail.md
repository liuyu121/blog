---
title: "Linux Cron Mail"
date: 2019-05-24T10:01:35+08:00
draft: false
categories: ["Linux"]
tags: ["linux","cron","mail"]
---

注：本文对一些信息做了处理，不影响核心逻辑。

## 一、背景介绍

### 1.1 问题发现

在线上某台机器上，手动执行脚本，发现报错 `Fatal Error`，提示有个类的常量未定义。

线上的 `crond` 一般都会配置 `MAILTO`，执行错误的脚本都会以邮件的形式发出来。但奇怪的是，这个脚本在 `crond` 部署很久了，为什么没收到相关的报警邮件呢？

### 1.2 问题分析

登录服务器看了下，发现其实 `/var/spool/mail/work` 下有很多邮件，通过查看 `/var/log/maillog`：

```shell
May 24 03:34:19 xxxxx sendmail[2049]: x4NJYJDR002049: to=root, ctladdr=root (0/0), delay=00:00:00, xdelay=00:00:00, mailer=relay, pri=30236, relay=[127.0.0.1] [127.0.0.1], dsn=4.0.0, stat=Deferred: Connection refused by [127.0.0.1]

```
怀疑是`sendmail` 没启动，于是 `service sendmail start`。测试发送了邮件后，仍然无法发出。看日志：

```shell
May 24 14:33:34 sendmail[27641]: x4J402nd011892: to=<mail@demo.com>, ctladdr=<root@localhost.localdomain> (0/0), delay=5+02:33:31, xdelay=00:00:00, mailer=esmtp, pri=10651048, relay=mxbiz2.qq.com., dsn=4.0.0, stat=Deferred: Connection timed out with mxbiz2.qq.com.
```
通常情况下，邮件都默认通过 `25端口`进行发送，`telnet` 看下，发现连接超时：

```shell
> telnet mxbiz2.qq.com 25

Trying 112.90.78.144...
telnet: connect to address 112.90.78.144: Connection timed out
Trying 163.177.89.176...
telnet: connect to address 163.177.89.176: Connection timed out
```
于是猜测阿里云封禁了 `TCP 25 端口`的 `出向流量`，所以连接失败。

我们知道常见的邮件服务器，一般使用 `25`、`465`、 `587` 等作为接收端口，所以尝试使用 `465` 端口进行发送。

```shell
> telnet smtp.exmail.qq.com 465

Trying 163.177.72.143...
Connected to smtp.exmail.qq.com.
Escape character is '^]'.
```
也即，`smtp.exmail.qq.com` 的 `465` 端口是可用的。于是尝试使用 `mailx` 通过 `smtps` 的方式发送邮件。

## 二、mailx 的安装与配置

### 2.1 一些解释

* 操作系统

```shell
> cat /proc/version

Linux version 2.6.32-696.23.1.el6.x86_64 (mockbuild@x86-01.bsys.centos.org) (gcc version 4.4.7 20120313 (Red Hat 4.4.7-18) (GCC) ) #1 SMP Tue Mar 13 22:44:18 UTC 2018
```
首先科普一下相关概念。

* 邮件用户代理（MUA，Mail User Agent）：如 `mailx`、`foxmail`等

* 邮件传送代理（MTA，Mail Transport Agent）：如 `sendmail`、`postfix`等

* 邮件分发代理（MDA，Mail Deliver Agent）：如 `procmail`

* sendmail：`sendmail - an electronic mail transport agent`，linux 各大发行版自带的邮件传输代理程序，一般作为默认的邮件处理程序。

* mailx：`mailx - send and receive Internet mail`，也即客户端，类似于各大邮箱的客户端等，配置 `smtp` 等，比 `sendmail` 要简单方便许多。

### 2.2 安装 && 配置 mailx

* 安装 mailx

```shell
yum install -y mailx
rpm -q mailx
```
* 关闭 `sendmail`、`postfix` 等服务

```shell
service sendmail stop
chkconfig sendmail off
service postfix stop
chkconfig postfix off
```
* 生成证书：

```shell
mkdir -p /root/.certs/
echo -n | openssl s_client -connect smtp.exmail.qq.com:465 | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > ~/.certs/qq.crt
certutil -A -n "GeoTrust SSL CA" -t "C,," -d ~/.certs -i ~/.certs/qq.crt
certutil -A -n "GeoTrust Global CA" -t "C,," -d ~/.certs -i ~/.certs/qq.crt
certutil -L -d /root/.certs
```
* 调整 `certs` 的位置，并授予相关权限 （这一步可做适当调整）

```shell
cp -r /root/.certs /etc/mail/qq-certs
chmod -R  755 /etc/mail/qq-certs/*
```
* 编辑 `vim /etc/mail.rc`，添加如下内容：

```shell
# user QQ smtp server
set from=mail@yourdomain.com
set smtp=smtps://smtp.exmail.qq.com:465
set smtp-auth-user= mail@yourdomain.com
set smtp-auth-password=xxxxxx
set smtp-auth=login
set ssl-verify=ignore
set nss-config-dir=/etc/mail/qq-certs
```
* 问题解决

解决如下报错：

```shell
Error in certificate: Peer's certificate issuer is not recognized.
```
需要信任证书：

```shell
cd /etc/mail/qq-certs
certutil -A -n "GeoTrust SSL CA - G3" -t "Pu,Pu,Pu" -d ./ -i qq.crt
```
成功则返回：

```shell
**Notice: Trust flag u is set automatically if the private key is present.**
```

## 三、crond 配合使用 mailx

### 3.1 cornd 直接配置 mailx

上面，我们已经配置好了 `mailx`，接下来讨论如何让 `crond` 使用其来发送邮件。

`crond` 可配置 `MAILTO=xx@mail.com` 将每个 `job` 的输出发送至 `job owner`, 默认是 `sendmail` 发送。在这里，我们需要改用 `mailx` 发送。

通过阅读 `man crond`，发现可用 `-m` 参数启动 `crond`，使用别的程序发送邮件。

```shell
   -m     This  option  allows  you to specify a shell command string to use for sending cron mail output
          instead of sendmail(8).  This command must accept a fully formatted mail message (with headers)
          on stdin and send it as a mail message to the recipients specified in the mail headers.             
```
首先编辑 `crond` 的配置 `vim /etc/sysconfig/crond`：

```shell
# Settings for the CRON daemon.
# CRONDARGS= :  any extra command-line startup arguments for crond

CRONDARGS="-m 'mailx -s test@yourdomain.com -t'"
```
需要重新启动 `crond`：

```shell
sudo /etc/init.d/crond restart
```
写个错误的 `cron`，等待其触发：
```
MAILTO=test@yourdomain.com

* * * * * liuduoyu echo "test cron mail 测试请忽略"
```
一分钟左右，收到了邮件，内容形如：

```email
From: root (Cron Daemon)
To: test@yourdomain.com
Subject: Cron <xxxx> liuduoyu echo "test cron mail 测试请忽略"
Content-Type: text/plain; charset=UTF-8

/* --- 省略 --- */

/bin/sh: liuduoyu: command not found
```
这里我们发现，虽然邮件成功接收，但是内容却不是我们想要的。

原因在于：`crond` 的输出，不能被 `mailx -t` 识别为一个有效的 `message header`，而是直接把其当做 `email body` 发出。

所以这里，需要考虑别的实现。

### 3.2 分析 crond 的运行机制

我们来看看 `crond` 究竟是如何处理 `-m` 参数的：

```shell
> ps aux | grep -i crond
root     25380  0.0  0.0 117328  1476 ?        Ss   May22   0:04 crond -m mailx
```
`strace` 该进程：

```shell
> strace -fp 25380 -s 1024 -e trace=process 2>&1 | grep mail
```
输出形如：

```shell
[pid  9002] execve("/bin/sh", ["/bin/sh", "-c", "liuduoyu echo \"xxxx mail test\""], [/* 9 vars */] <unfinished ...>
[pid  9024] execve("/bin/mailx", ["mailx", "-s", " Cron <xxxxx> liuduoyu echo \"xxxx mail test\"", "test@yourdomain.com"], [/* 6 vars */]) = 0
```
在这里我们可以推断出如下结论：

> `crond` 是将 `每个 job 的输出`，通过 `管道` 的形式，作为 `-m` 选项后配置的 `外部命令` 的 `STDIN` 传入。

所以，我们可以自行编写脚本，进行测试。

### 3.3 crond 配置 mailx 的脚本

我们已经知道，`crond` 会把每个子任务的输出，作为标准输入，通过管道，传给配置的邮件处理程序。那么，我们可以通过一个脚本，实现读取标准输入，进行文本处理，再发送邮件。

动手实现该逻辑的脚本 `vim ~/mailx-t`：

```shell

#!/bin/sh

# 需要接受 cron 管道的输出 也即 STDIN
## 这里用 argvs 是捕获不到的
body=''
line=0
flag=0 # flag the body
while read input
do
    line=$[ $line + 1 ]

    if [[ "$input" =~ "Subject" ]];then
        subject=`echo $input | awk -F ':' '{print $2}'`
    fi

    if [[ "$input" =~ "MAILTO" ]];then
        mailto=`echo $input | awk -F 'MAILTO=' '{print $2}' | awk -F '>' '{print $1}'`
    fi

    if [ $flag -eq 1 ];then
        flag=2
        body=$input
    elif [ $flag -eq 2 ];then
        body=$body"\n"$input
    fi
    if [[ "X$input" = "X" && !$flag ]];then
        ## start body
        flag=1
    fi
done

#echo "subject -> $subject";
#echo "mailto -> $mailto";
#echo "body -> $body";

## set default value
if [ "X$subject" = "X" ];then
    subject="[cron error] <`whoami`@`hostname`>"
fi;

if [ "X$body" = "X" ];then
    body="$subject"
fi;

if [ "X$mailto" = "X" ];then
    mailto="default@yourdomain.com"
fi;

exec echo -e $body | mailx -s "$subject" "$mailto"
```
配置到 `PATH` 下：

```shell
chmox +x ~/mailx-t
cp -r ~/mailx-t /usr/local/sbin/mailx-t
```

修改 `crond` 配置：

```shell
# Settings for the CRON daemon.
# CRONDARGS= :  any extra command-line startup arguments for crond

CRONDARGS="-m /usr/local/sbin/mailx-t"
```
重新启动 `crond`：

```shell
sudo /etc/init.d/crond restart
```
稍等一会儿，收到了报警邮件，内容形如：

```
邮件标题：Cron <xxx> liuduoyu echo "test cron mail测试请忽略" 

邮件正文：/bin/sh: liuduoyu: command not found
```

至此表明，`crond` 能成功使用 `mailx` 发送报警邮件了

## 四、一些思考


* `「单元测试」` 应该是每个程序员都必须具备的基本素质，文首提到的脚本的 `「Fatal Error」`应该在自测期间就能发现。

* 需要学会结合现象思考问题，熟练的使用 `linux` 下强大的命令工具集，探究问题发生的根本原因、解决方案等。

* 扩展的思考下，其实在这里，是不是也可以使用别的方式来实现呢？比如，使用 `php`来发送邮件。

* 对于 cron 任务过多的应用，应该将其 `web 化管理`