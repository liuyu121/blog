---
title: "PHP-FPM 配置与实现"
date: 2017-05-06T11:36:13+08:00
draft: false
categories: ["PHP"]
tags: ["php"]
---

## 配置

对于 `php-fpm` 的配置，其实无需阅读网上各种文章，因为大多数时候，`百度`搜索结果页前几页里，经常是重复的、概念性的、不全面的文章；或者在 `CSDN` 等网站上的文章，很多也是互相转载、互相 `copy`。

实际上，我们在了解、使用、优化 `php-fpm` 的时候，做好以下几件事即可：

* 查看 [`php 手册`](https://www.php.net/manual/zh/install.fpm.php)

* `man php-fpm`：查看 `php-fpm` 的命令，可以一窥可能用得到的选项。

* 阅读 `php-fpm.conf`：一些启动时的配置，如
	- `pid`
	- `erro_log`
	- `daemonize`：是否 `daemon` 形式运行，一般为 `yes`
	- `Pool Definitions` 的配置，一般在 `php-fpm.d` 目录下

* 阅读 `php-fpm.d/www.conf`：一般是配置某个 `pool`，多个则可多个文件（当然也可以放在同一个文件），一些重要的配置如
	
	- `prefix = /data/devops/php/php-fpm/pools/liuduoyu.com`
	
	- `user = _www`、`group = _www`：`woker` 所属用户与组
	
	- `listen = 127.0.0.1:9202`：也可以是 `sock` 文件 `/path/to/unix/socket`
	
	- `pm = dynamic`：很重要的配置，文件里有详细的解释三个不同的参数的区别。每种类型下，都有对应的其他指令。
	
	- `pm.max_children = 5`：最大的子进程数（上限，不能超过该配置数）
	
	- `pm.start_servers = 2`：启动时 `fork` 的 `worker` 数，可通过 `min_spare_servers + (max_spare_servers - min_spare_servers) / 2` 进行计算。
	
	- `pm.min_spare_servers = 1`：空闲（`idle state`）的 `worker` 数最小值，小于该值则创建新的 `worker`
	
	- `pm.max_spare_servers = 1`：空闲（`idle state`）的 `worker` 数最大值，大于该值则 `kill` 已存在的 `worker`
	
	- `pm.max_requests = 500`：单个 `woker` 处理的最大请求数，超过则会自动退出（防止`内存泄漏`）。
	
	- `pm.status_path = /fpm-status`：配置 `php-fpm` 的 `status page`，需要结合 `web server` 如 `nginx` 等使用。
	
	- `slowlog = log/$pool.log.slow`：慢日志，需要结合 `request_slowlog_*` 等配置使用。默认是 `10 s` 的阈值记录。
	
	- `;rlimit_files = 1024`：打开的最大文件句柄数，这个一般依赖 `操作系统` 的配置，如果服务器要启动很多个 `woker`，可能需要调整这个参数。
	
	- `env`：设置一些环境变量，需要设置 `clear_env = no`，然后测试 `env[AUTHOR] = LIUDUOYU`，在 `php` 代码中 `echo $_SERVER['AUTHOR'];`
	
	- `php_admin_value`：设置一些 `php.ini` 的配置，不能被 `ini_set` 覆盖
	
	- `php_flag`：设置一些 `php.ini` 的配置，能被 `ini_set` 覆盖

### 关于 `php-fpm status page` 的配置
 
* 使用 `Nginx`：
 
```shell
    location ~ ^/(fpm-status|fpm-ping)$ {
        add_header Access-Control-Allow-Origin *;
        access_log off;
        fastcgi_pass 127.0.0.1:9202;
        include fastcgi.conf;
        fastcgi_connect_timeout 5s;
        fastcgi_send_timeout 5s;
        fastcgi_read_timeout 5s;
        fastcgi_intercept_errors on;
    }
```
 
地址形如：

```url
 http://127.0.0.1/fpm-status?json&full
 http://127.0.0.1/fpm-status?full
```

* 可以使用自带的 `status.html`，在该页面的 `Status URL` 填写上述地址即可：
 
```file
/usr/local/Cellar/php/7.3.7/share/php/fpm/status.html
```

## 进程模型

典型的 `mster-worker` 进程模型，类似于 `nginx`。

`php-fpm` 的 `master` 进程，在初始化之后，然后执行 `fpm_run()`，随即进入一个事件循环中，(`fpm_event_loop()`)。

## 生命周期

... 待续
