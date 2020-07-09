#!/bin/bash

usage(){
    echo "Usage: `basename $0`
        new md-file-name : create the md file at content/post/md-file-name.md
        pull : pull repo && submodules"
}

new() {
    if test -z $1; then
        usage
        return
    fi

    name="${1}".md
    hugo new post/"${name}"
    open content/post/"${name}"
}

pull() {
    git pull
    git submodule foreach git pull%
}

cmd=$1
if [ "$cmd" = "new" ]; then
    new $2
elif [ "$cmd" = "pull" ]; then
    pull
else
    usage
fi