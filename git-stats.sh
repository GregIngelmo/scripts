#!/bin/sh

# Script to show the local and remote stats for current git repo
# useful for running in terminal pane alongside your code
# To keep this updated as you edit your code run
# fswatch --exclude "\.git" -o . | xargs -n1 -I {} git-stats.sh

clear && \
git fetch --quiet && \
echo "Unstaged changes" && \
git --no-pager diff --stat && \
echo "\nLocal commits" && \
git --no-pager log --pretty=format:"- %s (%cn)" origin/HEAD..HEAD && \
echo "\n\nRemote commits" && \
git --no-pager log --pretty=format:'- %s (%cn, %ar)' HEAD..origin/HEAD
