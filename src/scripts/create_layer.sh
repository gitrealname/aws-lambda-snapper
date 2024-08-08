#!/bin/bash

#echo env
echo "TARGETPLATFORM: ${TARGETPLATFORM}"
echo "USER_HOME_DIR: ${USER_HOME_DIR}"
echo "TARGETARCH: ${TARGETARCH}"
echo "TARGETOS: ${TARGETOS}"
echo "RUNTIME: ${RUNTIME}"
echo "RUNTIMEVER: ${RUNTIMEVER}"
echo "SDK: ${SDK}"

SYSTEM_RELEASE_VER=$(grep -Eo '[0-9\.]+' /etc/system-release)
echo "SYSTEM_RELEASE_VER: ${SYSTEM_RELEASE_VER}"
export SYSTEM_RELEASE_VER=$SYSTEM_RELEASE_VER

#set home directory
if [[ -z "${USER_HOME_DIR}" ]]; then
  USER_HOME_DIR="/root"
else
  USER_HOME_DIR="${USER_HOME_DIR}"
fi

${HOME}/scripts/create_${RUNTIME}_layer.sh

