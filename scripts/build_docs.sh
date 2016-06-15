#!/bin/sh

# only build doc for master branch
export SOURCE_BRANCH="master"
export DOC_BRANCH="gh-pages"

git fetch
git checkout $DOC_BRANCH

# this is the script actually build docs
./scripts/build_docs.sh

if [ "$TRAVIS_PULL_REQUEST" != "false" -o "$TRAVIS_BRANCH" != "$SOURCE_BRANCH" ]; then
    echo "Skipping deploy; just doing a build."
    exit 0
fi

# upload docs
./scripts/push_docs.sh
