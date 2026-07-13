#!/usr/bin/env bash

# exit script on any failing command
set -e

DEPLOY_REVISION="${DEPLOY_REVISION:-dev}"

PROJECT_DIR=`pwd`
PROJECT_BUILDIGNORE_FILE="${PROJECT_DIR}/.buildignore"
PROJECT_REVISION_FILE="${PROJECT_DIR}/public/REVISION"
PROJECT_BUILD_FILE="${PROJECT_DIR}/app.tgz"

BUILDER_FILE_PATH=`realpath $0`
BUILDER_DIR=`dirname ${BUILDER_FILE_PATH}`
BUILDIGNORE_FILE="${BUILDER_DIR}/.buildignore"

if [ -f $PROJECT_BUILDIGNORE_FILE ]; then
  echo "Using custom .buildignore"
  BUILDIGNORE_FILE=${PROJECT_BUILDIGNORE_FILE}
fi

echo "building ${DEPLOY_REVISION} deployment archive"

# write revision information from CI (tag:git-commit-hash)
echo ${DEPLOY_REVISION} > ${PROJECT_REVISION_FILE}

composer install --prefer-dist --no-progress --no-interaction --optimize-autoloader
npm i
npm run build
composer install --prefer-dist --no-progress --no-interaction --no-dev --optimize-autoloader
touch ${PROJECT_BUILD_FILE}

# Normalize archived file modes so deployed code is never writable by anyone but its
# owner (the deploy user), regardless of the CI runner umask — which otherwise leaks
# e.g. 0664/0775 group-writable files into the release and lets a compromised
# php-fpm/nginx process modify code. Default strips group + other WRITE (go-w): files
# become 0644, dirs 0755 — still readable/executable by the web-server user (via group
# or other), just not writable. Override the policy via DEPLOY_ARCHIVE_MODE (a
# chmod-style tar --mode spec, e.g. 'g-w,o-rwx' for stricter 0640/0750), or disable
# normalization entirely with DEPLOY_ARCHIVE_MODE="".
ARCHIVE_MODE="${DEPLOY_ARCHIVE_MODE-go-w}"
ARCHIVE_MODE_ARG=""
if [ -n "${ARCHIVE_MODE}" ]; then
  echo "normalizing archive permissions with --mode=${ARCHIVE_MODE}"
  ARCHIVE_MODE_ARG="--mode=${ARCHIVE_MODE}"
fi
tar -zc --no-xattrs ${ARCHIVE_MODE_ARG} --exclude-from=${BUILDIGNORE_FILE} -f ${PROJECT_BUILD_FILE} .
rm ${PROJECT_REVISION_FILE}
