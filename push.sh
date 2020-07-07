#!/bin/sh

publish() {
    # If a command fails then the deploy stops
    set -e

    printf "\033[0;32mDeploying updates to GitHub...\033[0m\n"
    
    # Build the project.
    hugo # if using a theme, replace with `hugo -t <YOURTHEME>`
    
    # Go To Public folder
    cd public
    
    # Add changes to git.
    git add .
    
    # Commit changes.
    msg="rebuilding site $(date)"
    if [ -n "$*" ]; then
        msg="$*"
    fi
    git commit -m "$msg"
    
    # Push source and build repos.
    git push origin master
}

deploy() {
    git add .
    git commit -m "update"
    git push origin master
}


cmd=$1
if [ "$cmd" = "p" ]; then
    publish
elif [ "$cmd" = "d" ]; then
    deploy
else
    publish
    deploy
fi
