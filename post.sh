#!/bin/bash

if test -z $1; then
    echo "need md file name"
    exit 1
fi

name="${1}".md
hugo new post/"${name}"
open content/post/"${name}"