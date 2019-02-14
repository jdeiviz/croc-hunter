#!/bin/bash

END=$1

for i in $(seq 1 $END)
do 
    git checkout feature-$i
    echo "# Feature-$i requirements" > README.md
    git commit -am "Updated feature-$i README.md"
    git push origin feature-$i
done

git checkout master