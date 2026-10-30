#!/usr/bin/env bash

# exit script on any failing command
set -e

BUILDER_FILE_PATH=$(realpath "${BASH_SOURCE[0]}")
BUILDER_DIR=$(dirname "${BUILDER_FILE_PATH}")

BUILD_REVISION_FILE=REVISION

source "${BUILDER_DIR}/build-common.sh"
