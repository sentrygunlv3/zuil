#!/bin/zsh
set -e

cd test

zig build "$@"

cd ..

test/zig-out/bin/test
