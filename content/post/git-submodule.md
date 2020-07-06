---
title: "Git Submodule 简单使用"
date: 2019-04-11T18:42:45+08:00
draft: false
categories: ["Git"]
tags: ["git","git-submodule","blog","hexo"]
---


之前把 `blog` 改用新的 `hexo` 来实现的时候，使用了 `next` 主题，开始尝试以 `git-submodule` 的方式引入。期间遇到了一些问题，以此文做记录。：）

## 添加子模块

添加子模块比较简单：

```git
git submodule add https://github.com/liuyu121/hexo-theme-next.git themes/next
```

## 拉取子模块

下面以 `clone` 我的 `blog` 举例，说明 `git submodule` 是如何使用的。

### 逐步获取

首先 `clone`：

```git
$ git clone https://github.com/liuyu121/liuyu121.github.io.git

正克隆到 'liuyu121.github.io'...
remote: Enumerating objects: 400, done.
remote: Counting objects: 100% (400/400), done.
remote: Compressing objects: 100% (95/95), done.
remote: Total 694 (delta 152), reused 385 (delta 139), pack-reused 294
接收对象中: 100% (694/694), 1.20 MiB | 683.00 KiB/s, 完成.
处理 delta 中: 100% (219/219), 完成.
```
我们观察当前有那些 `.git*` 的隐藏文件：

```shell
$ ls -alh . | grep -i git
drwxr-xr-x+ 12 liuyu  staff   384B  7 31 16:14 .git
```
然后查看 `.git/config` 文件的内容：

```shell
$ cat .git/config
[core]
	repositoryformatversion = 0
	filemode = true
	bare = false
	logallrefupdates = true
	ignorecase = true
	precomposeunicode = true
[remote "origin"]
	url = https://github.com/liuyu121/liuyu121.github.io.git
	fetch = +refs/heads/*:refs/remotes/origin/*
[branch "master"]
	remote = origin
	merge = refs/heads/master
```
这里因为我的 `blog` 的开发分支是 `gh-pages`，所以需要 `checkout` 过去。

```git
git co gh-pages
```
继续上述操作：

```shell
$ ls -alh . | grep -i git
drwxr-xr-x+ 12 liuyu  staff   384B  7 31 16:16 .git
-rw-r--r--+  1 liuyu  staff    65B  7 31 16:16 .gitignore
-rw-r--r--+  1 liuyu  staff   101B  7 31 16:16 .gitmodules

$ cat .git/config
[core]
	repositoryformatversion = 0
	filemode = true
	bare = false
	logallrefupdates = true
	ignorecase = true
	precomposeunicode = true
[remote "origin"]
	url = https://github.com/liuyu121/liuyu121.github.io.git
	fetch = +refs/heads/*:refs/remotes/origin/*
[branch "master"]
	remote = origin
	merge = refs/heads/master
[branch "gh-pages"]
	remote = origin
	merge = refs/heads/gh-pages
```
这时，发现了多了几个文件，我们查看 `.gitmodules` 的内容：

```shell
$ cat .gitmodules
[submodule "themes/next"]
	path = themes/next
	url = https://github.com/liuyu121/hexo-theme-next.git
```
也即，这个分支存在 `submodule`，但 `themes/next` 是空目录：

```
$ ls -alh themes/next/
total 0
drwxr-xr-x+ 2 liuyu  staff    64B  7 31 16:16 .
drwxr-xr-x+ 4 liuyu  staff   128B  7 31 16:16 ..
```
这个时候，就需要使用 `submodule` 相关命令，进行操作了。

* 首先，需要 `init`：

```shell
$ git submodule init
子模组 'themes/next'（https://github.com/liuyu121/hexo-theme-next.git）已对路径 'themes/next' 注册
```

通过查看 `git help submodule`，找到对 `init` 的解释（可参考上面的 `.gitmodules` 进行理解），这里会将 `url` 的 `repos` 注册至 `path`：

```shell
       init [--] [<path>...]
           Initialize the submodules recorded in the index (which were added and committed elsewhere) by setting
           submodule.$name.url in .git/config. It uses the same setting from .gitmodules as a template. If the URL is relative,
           it will be resolved using the default remote. If there is no default remote, the current repository will be assumed
```

查看 `.git/config`，发现最下面多了 `submodule` 开始的那几行，其中 `active = true` 表示已经 `注册` 了 `submodule`。

```shell
$ cat .git/config
[core]
	repositoryformatversion = 0
	filemode = true
	bare = false
	logallrefupdates = true
	ignorecase = true
	precomposeunicode = true
[remote "origin"]
	url = https://github.com/liuyu121/liuyu121.github.io.git
	fetch = +refs/heads/*:refs/remotes/origin/*
[branch "master"]
	remote = origin
	merge = refs/heads/master
[branch "gh-pages"]
	remote = origin
	merge = refs/heads/gh-pages
[submodule "themes/next"]
	active = true
	url = https://github.com/liuyu121/hexo-theme-next.git
```

* 接下来，获取 `submodule` 的代码。

```shell
$ git submodule update
正克隆到 '/Users/liuyu/liuyu/test/liuyu121.github.io/themes/next'...
子模组路径 'themes/next'：检出 '6ce32b8d7bc0a54ac735bf3e9b4d8592d9204f37'

$ ls  themes/next/
LICENSE.md      _config.yml     crowdin.yml     gulpfile.coffee layout          scripts         test
README.md       bower.json      docs            languages       package.json    source
```
其中，`update` 指令的作用可自行查阅。

通过以上几步，我们完整的 `pull` 了一个 `git-repos`，并大致了解了 `git submodule` 命令执行后，`git` 环境的一些变化。

对了，别忘了到 `submodule` 对应的目录下，切换分支（`update` 后处于 `HEAD（非分支）`状态）。

```shell
$ cd themes/next/
$ git co master
```

### 快捷操作

一般情况下，上面的命令会太繁琐，所以 `git` 提供了更方便的操作。

* 在 `colone` 的时候加上 `--recursive`，会发现在 `.git/config` 中已经存在了 `submodule` 的信息了。

```shell
git clone https://github.com/liuyu121/liuyu121.github.io.git --recursive

$ git co gh-pages

$ cat .git/config
[core]
	repositoryformatversion = 0
	filemode = true
	bare = false
	logallrefupdates = true
	ignorecase = true
	precomposeunicode = true
[submodule]
	active = .
[remote "origin"]
	url = https://github.com/liuyu121/liuyu121.github.io.git
	fetch = +refs/heads/*:refs/remotes/origin/*
[branch "master"]
	remote = origin
	merge = refs/heads/master
	
$ cat .gitmodules
[submodule "themes/next"]
	path = themes/next
	url = https://github.com/liuyu121/hexo-theme-next.git
```
* 再使用 `update` 获取数据：

```shell
$ git submodule update
```
* 其他一些常用命令：

```shell
# 一次性获取所有 submodule
git submodule foreach --recursive git submodule init 
git submodule foreach --recursive git submodule update 

# 查看 submodule 的文件信息
git submodule foreach ls -l

# 拉取所有 submodule
git submodule foreach git pull

```

## 删除子模块

据我了解，`git` 还没提供删除子模块的命令，所以总结了大致流程如下：

* ```git rm -r --cached [path]```

* 编辑 `.gitmodules` 文件，删除该子模块的相关配置

* 编辑 `.git/config` 文件，删除该子模块的相关配置

* 手动删除子模块残留的目录，如 `.git/modules/` 下对应目录等