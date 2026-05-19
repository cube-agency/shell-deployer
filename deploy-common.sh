#!/usr/bin/env bash

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 DEPLOYMENT_SOURCE_PATH" >&2
  exit 1
fi
DEPLOY_SOURCE_PATH=$1

# The last argument is expected to be the option --with-build
WITH_BUILD=false
if [[ " ${@: -1} " == *" --with-build "* ]]; then
  WITH_BUILD=true
  # Remove the last argument which is --with-build
  set -- "${@:1:$(($#-1))}"
fi

REQUIRED_VARS=("DEPLOY_HOST DEPLOY_USER DEPLOY_PATH")

for variableName in $REQUIRED_VARS; do
  if [[ -z "${!variableName}" ]]; then
    echo "${variableName} env variable is undefined"
    exit 1
  fi
done

DEPLOY_SSH_DIR=${HOME}/.ssh
DEPLOY_SSH_KNOWN_HOSTS_PATH=${DEPLOY_SSH_DIR}/known_hosts

checkExistingFile () {
  if test -f ${1}; then
    echo "${1} exists"
    exit 1
  fi
}

ensureSshDirExists() {
  # make sure that .ssh directory exists
  mkdir -p -m 700 ${DEPLOY_SSH_DIR}
}

upload() {
  echo "Uploading deployment"
  scp ${SCP_ARGS} -r ${DEPLOY_SOURCE_PATH} ${DEPLOY_USER}@${DEPLOY_HOST}:${1}
}

# optionally, write known hosts
if [ -n "${DEPLOY_SSH_KNOWN_HOSTS}" ]; then
  checkExistingFile ${DEPLOY_SSH_KNOWN_HOSTS_PATH}
  ensureSshDirExists

  # append known hosts
  echo "${DEPLOY_SSH_KNOWN_HOSTS}" >> ${DEPLOY_SSH_KNOWN_HOSTS_PATH}
fi

# optionally, write ssh key
if [ -n "${DEPLOY_SSH_PRIVATE_KEY}" ] && [ -n "${DEPLOY_SSH_PRIVATE_KEY_BASE64}" ]; then
  echo "Error: set only one of DEPLOY_SSH_PRIVATE_KEY or DEPLOY_SSH_PRIVATE_KEY_BASE64" >&2
  exit 1
fi

if [ -n "${DEPLOY_SSH_PRIVATE_KEY}" ] || [ -n "${DEPLOY_SSH_PRIVATE_KEY_BASE64}" ]; then
  DEPLOY_SSH_PRIVATE_KEY_PATH=${DEPLOY_SSH_DIR}/id_rsa

  checkExistingFile ${DEPLOY_SSH_PRIVATE_KEY_PATH}
  ensureSshDirExists

  if [ -n "${DEPLOY_SSH_PRIVATE_KEY_BASE64}" ]; then
    if ! echo "${DEPLOY_SSH_PRIVATE_KEY_BASE64}" | base64 -d > ${DEPLOY_SSH_PRIVATE_KEY_PATH}; then
      echo "Error: failed to base64-decode DEPLOY_SSH_PRIVATE_KEY_BASE64" >&2
      exit 1
    fi
  else
    echo "${DEPLOY_SSH_PRIVATE_KEY}" > ${DEPLOY_SSH_PRIVATE_KEY_PATH}
  fi

  chmod 600 ${DEPLOY_SSH_PRIVATE_KEY_PATH}
fi

# build ssh args
SSH_ARGS=""
SCP_ARGS=""

# optionally, specify ssh key
if [ -n "${DEPLOY_SSH_PRIVATE_KEY_PATH}" ]; then
  SSH_ARGS="${SSH_ARGS} -i ${DEPLOY_SSH_PRIVATE_KEY_PATH}"
  SCP_ARGS="${SCP_ARGS} -i ${DEPLOY_SSH_PRIVATE_KEY_PATH}"
fi

# optionally, specify ssh port
if [ -n "${DEPLOY_SSH_PORT}" ]; then
  SSH_ARGS="${SSH_ARGS} -p ${DEPLOY_SSH_PORT}"
  SCP_ARGS="${SCP_ARGS} -P ${DEPLOY_SSH_PORT}"
fi

# optionally, run build command
if [ "${WITH_BUILD}" = true ]; then
  ${DEPLOYER_DIR}/build-${DEPLOY_TYPE}.sh
fi


RELEASE=`date -u +%Y%m%d%H%M%S`
RELEASE_DIR=${DEPLOY_PATH}/releases/${RELEASE}
