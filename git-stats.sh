#!/bin/sh

# Script to show that local and remote stats for current git repo
# useful for running in terminal pane alongside your code
# To keep this updated as you edit your code run
# fswatch --exclude "\.git" -o . | xargs -n1 -I {} git-stats.sh

# Print pretty colors 
keyColor='[38;5;67m' # light blue [0m 
valColor='[38;5;34m' # green      [0m 
errColor='[38;5;124m' # red       [0m 
noColor='[0m'

printMsg(){
    msg=$1
    echo "${keyColor}$msg${noColor}"
}

clear
git fetch --quiet
printMsg "Untracked files"
git ls-files . --exclude-standard --others | xargs -I {} echo - {}
printMsg "\nUnstaged changes"
git --no-pager diff --stat
printMsg "\nStaged changes"
git --no-pager diff --stat --staged
printMsg "\nLocal commits"
git --no-pager log --pretty=format:"- %h %s (%cn)" origin/HEAD..HEAD
printMsg "\nRemote commits"
git --no-pager log --pretty=format:'- %h %s (%cn, %ar)' HEAD..origin/HEAD
