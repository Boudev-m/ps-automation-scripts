#!/usr/bin/env powershell

git add *
Write-Host "The files are staged."
$commit = Read-Host "Please enter your commit"
git commit -m $commit
git push origin master
git branch -d gh-pages
git branch gh-pages
git push origin gh-pages