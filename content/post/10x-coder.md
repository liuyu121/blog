---
title: "10x Coder"
date: 2020-07-07T19:53:51+08:00
lastmod: 2020-07-07T19:53:51+08:00
draft: false
categories: ["Tech"]
tags: ["Tech"]

---

牛逼的工具集，必须能事半功倍。

下面参考链接是来自于网上一些大牛的分享，大牛是`100x programmer`，我觉着 `10x coder` 就已经很牛逼了（难。:yum:

* [How to be a 100x Programmer?](https://crispgm.com/page/how-to-be-a-100x-programmer.html)
* [高能分享之《优雅的编程者》](http://xiaorui.cc/archives/6643)

常用电脑是 `mac`，所以本文相关工具都是基于 `mac` 系统，在其他系统上可能出现不可用、或使用姿势有差别，但更多的都是可跨平台使用软件。

## 装机必备篇

`Mac` 装机必备软件，真心的要有，否则就真心的不及格 ：）

啊，真心赞美这些伟大的开源软件大神们~

### Homebrew

[https://brew.sh/](https://brew.sh/)

不必多说，神器。

因为是 `ruby` 写的，看着某个功能不爽可自行编辑，毕竟 修改 `ruby` 代码不需要懂语法：）

### iTerm2

[https://www.iterm2.com/](https://www.iterm2.com/)

神器`+10086`，全面吊打自带的终端。

至于 `shell` 版本，`Mac` 默认已经是 `zsh` 了（`bash` 太落后了），具体配置，大神已经给你准备好了，[https://ohmyz.sh/](https://ohmyz.sh/)。

不过对于`oh-my-zsh` 下的 `git`配置，我觉得不讨喜，个人更喜欢这种：[Git Shell 便捷设置](https://liuyu121.github.io/post/git-shell-config/)。

`tips`：

* 罗技鼠标在 `iterm2`里不生效，需要 [设置](https://mikebuss.com/2019/12/30/logitech-scrolling/) ，去掉 `Secure Keyboard Entry`这个选项即可（曾经困扰半天）。

### Typora

[https://typora.io/](https://typora.io/)

习惯了使用 `markdown` 写东西，简单直接，下面是之前用过的一些编辑器：

* `mou`：某国人写的一个所见即所得编辑器，分屏展示效果。
* `macdown`：基于 `mou` 的改造。
* `印象笔记`：不忍吐槽 

现在该`markdown` 神之编辑器出场了： `Typora` 。

不管是 `UI` 、交互还是人性化，都是大写的牛逼。全屏模式下的沉浸式写作，简直让人欲罢不能。

#### Typora Tips

持续更新一些 `tips`。

* 不继承上一行格式：`mac` 下使用 `command+[`，比如在列表换行，必须要知道这个快捷键，否则，你懂的。
* `emoji list`：[https://gist.github.com/rxaviers/7360908](https://gist.github.com/rxaviers/7360908)
* 常用的快捷键：
  * 超链接：`command+k`，选中文本后，`Typora`能自动识别剪贴板的 `url`，生成超链接。
  * 内联公式：`control+`;` 我喜欢把数字和英文加上该样式，所以特别实用。

### v2ray

https://github.com/v2ray/v2ray-core

你懂的，`ss`被喝茶后，哀嚎一片，这尼玛都`0202年了`，墙你妈呢~

### VIM

不会用 `emacs`又如何，`vim`足够了。

关于 `vim`的配置也一大堆，按照个人喜好来就行。之前基于`vim`下开发了段时间，各种插件，但最后终究还是现代编辑器真香（`VsVode`、`intellij `家族），但还是得感谢那段时间的使用，对于这些上古玩意，就讲究一个熟能生巧 ：）

## 进阶篇

### tig

[https://github.com/jonas/tig](https://github.com/jonas/tig)

你会告别 `git log --xxxx`，但坏处是，会让你忘记 `git log --xxxx`。

但真的很方便。

### tmux

[https://github.com/tmux/tmux](https://github.com/tmux/tmux)

注意，所谓前置快捷键 `ctrl+b`是指按下这俩键后松手，再按其他快捷键，否则会很迷惑。

各种快捷键，熟能生巧。

### 小工具

* `dos2unix`：顾名思义，在 `win`下`copy`的文件，因为换行符不一样，会导致行数计算等有问题，直接`dos2unix` 下即可。

### Tips

* `open`：学会在终端使用该命令，简单快捷，然后放在 `shell` 脚本里，美滋滋。



