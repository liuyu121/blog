#!/bin/sh

publish() {
    echo "============================== publish start ==============================\n"

    # If a command fails then the deploy stops
    set -e

    printf "\033[0;32mDeploying updates to GitHub...\033[0m\n"
    
    # Build the project.
    hugo # if using a theme, replace with `hugo -t <YOURTHEME>`
    
    # Go To Public folder
    cd public
    
    # Add changes to git.
    git add .
    
    set +e

    # Commit changes.
    msg="rebuilding site $(date)"
    if [ -n "$*" ]; then
        msg="$*"
    fi
    git commit -m "$msg"
    
    if [ $? = 0 ]; then
        # Push source and build repos.
        git push origin master
    fi
    echo "\n============================== publish end =============================="
}

deploy() {
    echo "============================== deploy end ==============================\n"
    set +e
    git add .
    git commit -m "update"
    git push origin master
    echo "============================== deploy end ==============================\n"
}


cmd=$1
if [ "$cmd" = "p" ]; then
    publish
elif [ "$cmd" = "d" ]; then
    deploy
else
    publish

    echo "\n"
    cd ..

    deploy
fi
