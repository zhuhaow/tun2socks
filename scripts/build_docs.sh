#!/bin/sh

git checkout gh-pages
git submodule update --remote
jazzy
