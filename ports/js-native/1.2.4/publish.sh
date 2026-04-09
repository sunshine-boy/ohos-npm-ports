#!/bin/sh
set -e

cd package
npm publish --tag latest --access public
