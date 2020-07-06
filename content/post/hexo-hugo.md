---
title: "Hexo 迁移至 Hugo"
date: 2020-07-06T18:45:20+08:00
draft: false
categories: ["Blog"]
tags: ["blog"]

---

`blog` 之前用的是 `hexo` 来实现，但换新环境都要搞一大堆东西，很麻烦，所以荒废了好久没写什么东西了。

这段时间打算迁移到 `hugo`[^pa1]，一个 `go` 写的生成静态博客的工具，生成速度极快，且能关联到 `github-pages`。

这篇文章简单记录如何使用 `hugo`，以及如何与 `github-pages` 打通。

`hugo` 具体使用可参考官方文档，上手及其简单，我使用的是 `next ` 主题[^pa2]。

配置 `github-pages` 也较简单，且支持多种配置方式，我采用了`GitHub User or Organization Pages`[^pa3] 的方式，大体步骤如下：

* 新建一个 `blog` 的 `repo`，将本地的 `hugo` 目录导入至该 `repo`。

* 添加 `public` 目录至 `gitignore`，保存官网提供的 `deploy.sh` ，然后提交到远程。

* 将 `github-pages` 的 `repo` 以 `submodule`  引入至 `hugo` 的 `public` 目录，注意，如果需要先删除本地的 `public` 目录（如果存在）。

* 将 `github` 的 `repo` 作为 `submodule` 引入至 `public`，这样每次 `hugo` 生成的静态文件就直接 `push` 到了该 `repo`。

* 关键操作如下

```shell
git remote add origin https://github.com/liuyu121/blog.git
echo "public" >> .gitignore
vim depoy.sh

rm -rf public
git submodule add  -f  -b master https://github.com/liuyu121/liuyu121.github.io.git public
```

以上，操作简单方便，没有一堆 `nodejs` 的依赖，生成速度极快，可见即所得。

[^pa1]: [hugo 官网](https://gohugo.io/)

[^pa2]: [hugo-theme-even](https://github.com/olOwOlo/hugo-theme-even)

[^pa3]: [hosting-on-github](https://gohugo.io/hosting-and-deployment/hosting-on-github)