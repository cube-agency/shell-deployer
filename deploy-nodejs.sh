#!/usr/bin/env bash

# exit script on any failing command
set -e

DEPLOYER_FILE_PATH=$(realpath "${BASH_SOURCE[0]}")
DEPLOYER_DIR=$(dirname "${DEPLOYER_FILE_PATH}")
DEPLOY_TYPE=nodejs

source "${DEPLOYER_DIR}/deploy-common.sh"

# silence file upload
SCP_ARGS="${SCP_ARGS} -q"

# create release directory
echo "Deploying release ${RELEASE}"
ssh ${SSH_ARGS} ${DEPLOY_USER}@${DEPLOY_HOST} /bin/bash << EOT
  # exit script on any failing command
  set -e

  mkdir -p ${DEPLOY_PATH}/releases
EOT

# call upload method by specifying upload target
upload ${RELEASE_DIR}

# run deploy commands and switch to the release
ssh ${SSH_ARGS} ${DEPLOY_USER}@${DEPLOY_HOST} /bin/bash << EOT
  # exit script on any failing command
  set -e

  # use ; as delimiter for list params, without expanding glob characters in commands
  export IFS=";"
  set -f

  # change working directory
  cd ${RELEASE_DIR}

  # deploy commands, run in the release directory before it becomes current
  export LOCAL_DEPLOY_COMMANDS=$(quote "${DEPLOY_COMMANDS}")
  for deploy_command in \${LOCAL_DEPLOY_COMMANDS}; do
    echo "\${deploy_command}"
    bash -c "\${deploy_command}"
  done

  # switch the current symlink to this release
  echo "Switching to release ${RELEASE}"
  ln -sTf ${RELEASE_DIR} ${DEPLOY_PATH}/current

  # finalize commands, run from the live current directory
  cd ${DEPLOY_PATH}/current
  export LOCAL_DEPLOY_FINALIZE_COMMANDS=$(quote "${DEPLOY_FINALIZE_COMMANDS}")
  for finalize_command in \${LOCAL_DEPLOY_FINALIZE_COMMANDS}; do
    echo "\${finalize_command}"
    bash -c "\${finalize_command}"
  done

  # delete all release directories except the ${DEPLOY_KEEP_RELEASES} latest
  echo "Cleaning up old releases"
  set +f
  ls -dr ${DEPLOY_PATH}/releases/* | tail -n +$((DEPLOY_KEEP_RELEASES + 1)) | xargs rm -fr
EOT
