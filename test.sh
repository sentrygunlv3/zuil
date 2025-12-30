#!/bin/zsh
set -e

cd test

zig build

./zig-out/bin/test
