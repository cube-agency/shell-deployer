#!/usr/bin/env bash

# exit script on any failing command
set -e

DEPLOYER_FILE_PATH=$(realpath "${BASH_SOURCE[0]}")
DEPLOYER_DIR=$(dirname "${DEPLOYER_FILE_PATH}")

# laravel defaults for deploy-php; an explicit empty value disables the option
export DEPLOY_TYPE=laravel
export DEPLOY_SHARED_FILES="${DEPLOY_SHARED_FILES-.env}"
export DEPLOY_SHARED_DIRECTORIES="${DEPLOY_SHARED_DIRECTORIES-storage}"
export DEPLOY_SHARED_CREATE_DIRECTORIES="${DEPLOY_SHARED_CREATE_DIRECTORIES-storage/app/public;storage/framework/cache/data;storage/framework/views;storage/framework/sessions;storage/logs}"
export DEPLOY_SHARED_REQUIRED_PATHS="${DEPLOY_SHARED_REQUIRED_PATHS-.env}"

# artisan commands run as "<DEPLOY_PHP_COMMAND> artisan <command>" ahead of DEPLOY_COMMANDS
DEPLOY_PHP_COMMAND="${DEPLOY_PHP_COMMAND:-php}"
DEPLOY_ARTISAN_COMMANDS="${DEPLOY_ARTISAN_COMMANDS-storage:link;config:cache;migrate --force;view:cache;queue:restart}"

ARTISAN_DEPLOY_COMMANDS=""
IFS=";"
set -f
for artisan_command in ${DEPLOY_ARTISAN_COMMANDS}; do
  [ -n "${artisan_command}" ] || continue
  ARTISAN_DEPLOY_COMMANDS="${ARTISAN_DEPLOY_COMMANDS}${DEPLOY_PHP_COMMAND} artisan ${artisan_command};"
done
set +f
unset IFS

# join the two lists, dropping the separators left by empty lists
DEPLOY_COMMANDS="${ARTISAN_DEPLOY_COMMANDS}${DEPLOY_COMMANDS}"
DEPLOY_COMMANDS="${DEPLOY_COMMANDS%;}"
export DEPLOY_COMMANDS

exec "${DEPLOYER_DIR}/deploy-php.sh" "$@"
