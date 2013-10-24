#!/bin/bash
set -x
set -e

build="$(mktemp -d)"
target="$(readlink -f "$1")"

cleanup() {
  rm -rf "$build"
}

#trap cleanup EXIT

pip install --download "$build" --no-deps -r requirements.txt
pushd "$build"

for tgz in *.tar.gz
do
    tar -xzf "$tgz"
done
for tbz2 in *.tar.bz2
do
    tar -xjf "$tbz2"
done
for zip in *.zip
do
    unzip "$zip"
done

popd

patch -d "$build" -p0 < rpm-build-patches.diff

pushd "$build"
for egg in $(find . -mindepth 1 -maxdepth 1 -type d)
do
    pushd "$egg"
    python setup.py bdist_rpm
    rm dist/*.src.rpm
    rm dist/*.tar.gz
    popd
    mv $egg/dist/* "$target"
done
popd

