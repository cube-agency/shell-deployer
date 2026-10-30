#!/usr/bin/env bash

# exit script on any failing command
set -e

DEPLOYER_FILE_PATH=$(realpath "${BASH_SOURCE[0]}")
DEPLOYER_DIR=$(dirname "${DEPLOYER_FILE_PATH}")

# wordpress defaults for deploy-php; an explicit empty value disables the option
export DEPLOY_TYPE=wordpress
export DEPLOY_SHARED_FILES="${DEPLOY_SHARED_FILES-.env}"
export DEPLOY_SHARED_DIRECTORIES="${DEPLOY_SHARED_DIRECTORIES-wp-content/uploads;wp-content/languages}"
export DEPLOY_SHARED_REQUIRED_PATHS="${DEPLOY_SHARED_REQUIRED_PATHS-.env}"

exec "${DEPLOYER_DIR}/deploy-php.sh" "$@"
