git fetch --all
git checkout master
git merge origin/main --allow-unrelated-histories --strategy-option theirs --no-edit
git push
git checkout main
