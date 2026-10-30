#!/usr/bin/env bash

# exit script on any failing command
set -e

DEPLOYER_FILE_PATH=$(realpath "${BASH_SOURCE[0]}")
DEPLOYER_DIR=$(dirname "${DEPLOYER_FILE_PATH}")
# wrappers such as deploy-laravel set DEPLOY_TYPE to select their build script
DEPLOY_TYPE="${DEPLOY_TYPE:-php}"

source "${DEPLOYER_DIR}/deploy-common.sh"

DEPLOY_SOURCE_NAME=$(basename "${DEPLOY_SOURCE_PATH}")

# ; separated lists of paths relative to both DEPLOY_PATH/shared and the release
# directory, each empty unless the caller sets it:
#   DEPLOY_SHARED_FILES               symlinked into the release
#   DEPLOY_SHARED_DIRECTORIES         created in shared and symlinked into the release
#   DEPLOY_SHARED_CREATE_DIRECTORIES  created in shared
#   DEPLOY_SHARED_REQUIRED_PATHS      must exist in shared before anything is uploaded
#
# shared paths are removed from the release before being symlinked, so they must
# stay inside the release directory
validateRelativePaths() {
  local variableName=$1
  local IFS=";"
  set -f
  for path in ${!variableName}; do
    case "${path}" in
      /*|..|../*|*/..|*/../*|*/)
        echo "${variableName} entry '${path}' must be a relative path without .. or a trailing slash" >&2
        exit 1
        ;;
    esac
  done
  set +f
}

validateRelativePaths DEPLOY_SHARED_FILES
validateRelativePaths DEPLOY_SHARED_DIRECTORIES
validateRelativePaths DEPLOY_SHARED_CREATE_DIRECTORIES
validateRelativePaths DEPLOY_SHARED_REQUIRED_PATHS

# a shared path inside another one would be removed through the outer symlink on the
# server, and is reachable through it anyway
validateNoNestedPaths() {
  local IFS=";"
  set -f
  local paths=(${DEPLOY_SHARED_FILES} ${DEPLOY_SHARED_DIRECTORIES})
  set +f
  local outer inner
  for outer in "${paths[@]}"; do
    for inner in "${paths[@]}"; do
      case "${inner}" in
        "${outer}"/?*)
          echo "shared path '${inner}' is inside shared path '${outer}'" >&2
          exit 1
          ;;
      esac
    done
  done
}

validateNoNestedPaths

echo "Deploying release ${RELEASE}"
# check the required shared paths, then create the release and shared directories
ssh ${SSH_ARGS} ${DEPLOY_USER}@${DEPLOY_HOST} /bin/bash << EOT
  # exit script on any failing command
  set -e

  # use ; as delimiter for list params, without expanding glob characters in paths
  export IFS=";"
  set -f

  # do not go further as required shared paths are not created yet
  export LOCAL_DEPLOY_SHARED_REQUIRED_PATHS=$(quote "${DEPLOY_SHARED_REQUIRED_PATHS}")
  for shared_required_path in \${LOCAL_DEPLOY_SHARED_REQUIRED_PATHS}; do
    if [ ! -e "${DEPLOY_PATH}/shared/\${shared_required_path}" ]; then
      echo "${DEPLOY_PATH}/shared/\${shared_required_path} does not exist"
      exit 1
    fi
  done

  mkdir -p ${RELEASE_DIR}

  # create shared directories
  export LOCAL_DEPLOY_SHARED_DIRECTORIES=$(quote "${DEPLOY_SHARED_DIRECTORIES}")
  export LOCAL_DEPLOY_SHARED_CREATE_DIRECTORIES=$(quote "${DEPLOY_SHARED_CREATE_DIRECTORIES}")
  for shared_directory in \${LOCAL_DEPLOY_SHARED_DIRECTORIES} \${LOCAL_DEPLOY_SHARED_CREATE_DIRECTORIES}; do
    mkdir -p "${DEPLOY_PATH}/shared/\${shared_directory}"
  done
EOT

# call upload method by specifying upload target
upload ${RELEASE_DIR}/${DEPLOY_SOURCE_NAME}

# extract the archive, link shared paths, run the commands and switch to the release
ssh ${SSH_ARGS} ${DEPLOY_USER}@${DEPLOY_HOST} /bin/bash << EOT
  # exit script on any failing command
  set -e

  # use ; as delimiter for list params, without expanding glob characters in paths
  export IFS=";"
  set -f

  # change working directory
  cd ${RELEASE_DIR}

  # extract and remove archive
  tar xzf ${DEPLOY_SOURCE_NAME}
  rm ${DEPLOY_SOURCE_NAME}

  # symlink shared files and directories, replacing anything archived at the same path
  export LOCAL_DEPLOY_SHARED_FILES=$(quote "${DEPLOY_SHARED_FILES}")
  export LOCAL_DEPLOY_SHARED_DIRECTORIES=$(quote "${DEPLOY_SHARED_DIRECTORIES}")
  for shared_path in \${LOCAL_DEPLOY_SHARED_FILES} \${LOCAL_DEPLOY_SHARED_DIRECTORIES}; do
    [ -n "\${shared_path}" ] || continue
    rm -rf "\${shared_path}"
    mkdir -p "\$(dirname "\${shared_path}")"
    ln -s "${DEPLOY_PATH}/shared/\${shared_path}" "\${shared_path}"
  done

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
