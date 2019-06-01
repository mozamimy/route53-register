#!/bin/bash

set -o errexit
set -o pipefail
set -o noclobber
set -o xtrace

cargo fmt -- --check

if [[ -z "$RELEASE" ]]; then
  cargo build
  cd target/debug
else
  cargo build --release --locked
  cd target/release
fi

zip bootstrap.zip bootstrap
