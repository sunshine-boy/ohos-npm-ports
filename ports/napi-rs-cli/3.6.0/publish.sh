#!/bin/sh
set -e

PKG_NAME="napi-rs-cli"
UPSTREAM_VERSION="3.6.0"

cd "${PKG_NAME}-${UPSTREAM_VERSION}"
npm publish --tag latest --access public
