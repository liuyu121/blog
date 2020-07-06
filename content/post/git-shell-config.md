---
title: "Git Shell 便捷设置"
date: 2015-04-12T19:26:53+08:00
draft: false
categories: ["Git"]
tags: ["git","shell"]
---


* 注：可使用 [zsh](https://ohmyz.sh/)
* 工具推荐：请安装 [tig](http://jonas.github.io/tig/) `brew install tig`

为了更好、更方便的在 `shell` 下操作 `git`，下面介绍一些常用的 `git` 配置等，以供参考。

本机相关环境：

* 操作系统：

```shell
	# sw_vers
	ProductName:	Mac OS X
	ProductVersion:	10.14.2
	BuildVersion:	18C54
	macOS 10.14.2
```

* git 版本：

```shell
	# git --version
	git version 2.7.3
```

## 配置 git 补全

`git 补全脚本`，可以更好的帮助我们使用 `git`，省去大量不必要的输入。

当然，该脚本建议是在对 `git` 命令行有一定熟悉后再使用。

* 下载补全脚本

```shell
curl -OsSL 'https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash'
```

* 将该脚本重命名并 `mv 到 home 目录`

```shell
mv git-completion.bash ~/.git-completion.bash
```

## gitconfig 配置

好的 `gitconfig` 配置，如 `git alias` 的设置，也会给我们带来极大的便利性。

> cat ~/.gitconfig

```git
[user]
    name = yourname
    email = yourname@email.com
[merge]
    tool = vimdiff
[color]
    diff = auto
    status = auto
    branch = auto
    interactive = true
[core]
    symlinks = false
    autocrlf = false
    quotepath = false
    editor = vim
    excludesfile = /path/to/.gitignore
[i18n]
    commitencoding = UTF-8
[push]
    default = simple
[filter "media"]
    clean = git-media-clean %f
    smudge = git-media-smudge %f
[alias]
    ci = commit
    ca = commit -a
    cia = commit --amend
    di = diff --ignore-space-at-eol -w -b
    dic = diff --cached
    wc = whatchanged --oneline
    ss = stash list
    st = status
    s = status -sb
    br = branch
    rb = branch -r
    b = branch -a -v
    bm = branch --merged
    bn = branch --no-merged
    co = checkout
    w = shortlog -s -n --since='1 week ago' --no-merges
    m = shortlog -s -n --since='1 month ago' --no-merges
    d = shortlog -s -n --since='2 day ago' --no-merges
    hd = log -2 HEAD
    h = !git log --pretty=format:\"%Cred%an%Creset@%ar - %Cgreen%s%Creset\"
    his = !git log --numstat --pretty=format:\"%Cred%an%Creset@%ar %Cgreen%s%Creset\" HEAD
    lg = log --date=local
    ls = log --stat --summary --date=local
    ll = log -p --date=local
    llw = log -p --date=local --word-diff
    u = log --stat --summary --date=local --author
    uu = log -p --date=local --author
    bl = blame --show-stats
    bls = blame --show-stats -s
    rem = remote -v
    unstage = reset HEAD --
    datetag = !git tag `date \"+%Y%m%d%H%M\"`
    ds = diff --stat=800,500
    dm = diff --stat=800,500 master
    conf = config -l
    parent = "!git show-branch | grep '*' | grep -v \"$(git rev-parse --abbrev-ref HEAD)\" | head -n1 | sed 's/.*\\[\\(.*\\)\\].*/\\1/' | sed 's/[\\^~].*//' #"
[diff "bin"]
    textconv = hexdump -v -C
[credential]
    helper = osxkeychain
    helper = store --file ~/.git-credentials
    helper = cache --timeout 30000

```

## 配置 git shell 提示

最后，我们可以在终端，配置一些色彩和路径的 tip，对我们 `git` 的使用以及代码操作有很大帮助。

> 配置终端色彩、提示等：```vim ~/.bash_profile```

```shell
# Terminal colours (after installing GNU coreutils)
NM="\[\033[0;38m\]" #means no background and white lines
HI="\[\033[0;37m\]" #change this for letter colors
HII="\[\033[0;31m\]" #change this for letter colors
SI="\[\033[0;33m\]" #this is for the current directory
IN="\[\033[0m\]"

# Git branch in prompt.
RED="\033[33;31m"
GREEN="\033[33;32m"
YELLOW="\033[33;33m"
BLUE="\033[33;34m"
PURPLE="\033[33;35m"
RESET="\033[m"

# git 提示
function parse_git_branch {
        log=$(git status -sb 2> /dev/null)

        OLD_IFS="$IFS"
        IFS=$(echo -e "\n\b")
        arr=($log)
        IFS="$OLD_IFS"

        git_branch="${arr[0]:3}"
        if [ ${#git_branch} -gt 0 ]; then
                if [ ${#arr[@]} -gt 1 ]; then
                        git_branch="${RED}($git_branch)${RESET}"
                else
                        git_branch="${GREEN}($git_branch)${RESET}"
                fi
        fi
        echo -e " ${git_branch} "
}

# 设置提示符合
export PS1="$NM[ $HI\u $HII\h $SI\w$NM$HII\$(parse_git_branch)$NM] \n$ $IN"

# 执行 git 补全脚本
if [ -f ~/.git-completion.bash ]; then
	. ~/.git-completion.bash
fi

```

> 添加一些常用的 `bash alias` ：```vim ~/.bash_profile```

```shell
alias gitdiffmaster="git log --stat=800,1000  master..HEAD  | egrep '(.*)\|' | sed 's/\(.*\)|\(.*\)/\1/g' |  awk '{print $1}' | sort -u  | grep -v tpl | grep -v css | grep -v js | sort -u"
alias gitbr='for branch in `git branch -r | grep -v HEAD`;do echo -e `git show --format="%ci %cr %an" $branch | head -n 1` \\t$branch; done | sort -r'

```