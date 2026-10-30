#!/usr/bin/env bash

# shared by build-laravel and build-wordpress; the caller sets BUILDER_DIR and
# BUILD_REVISION_FILE, the path receiving DEPLOY_REVISION relative to the project

DEPLOY_REVISION="${DEPLOY_REVISION:-dev}"

PROJECT_DIR=$(pwd)
PROJECT_BUILDIGNORE_FILE="${PROJECT_DIR}/.buildignore"
PROJECT_REVISION_FILE="${PROJECT_DIR}/${BUILD_REVISION_FILE}"
PROJECT_BUILD_FILE="${PROJECT_DIR}/app.tgz"

BUILDIGNORE_FILE="${BUILDER_DIR}/.buildignore"

if [ -f "${PROJECT_BUILDIGNORE_FILE}" ]; then
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

# Normalize archived file modes so deployed code is writable by its owner (the deploy
# user) only, regardless of the CI runner umask. The default strips the group and other
# write bits (go-w): files become 0644 and directories 0755, still readable and
# executable by the web-server user but not modifiable by a compromised php-fpm or
# nginx process. DEPLOY_ARCHIVE_MODE takes a chmod-style tar --mode spec, for example
# 'g-w,o-rwx' for a stricter 0640/0750; an empty value disables the normalization.
ARCHIVE_MODE="${DEPLOY_ARCHIVE_MODE-go-w}"
ARCHIVE_MODE_ARG=""
if [ -n "${ARCHIVE_MODE}" ]; then
  echo "normalizing archive permissions with --mode=${ARCHIVE_MODE}"
  ARCHIVE_MODE_ARG="--mode=${ARCHIVE_MODE}"
fi
tar -zc --no-xattrs ${ARCHIVE_MODE_ARG} --exclude-from=${BUILDIGNORE_FILE} -f ${PROJECT_BUILD_FILE} .
rm ${PROJECT_REVISION_FILE}
