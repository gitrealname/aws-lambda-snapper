#!/bin/bash

#This is just a helper to debug while on playground!

#echo env
SYSTEM_RELEASE_VER=$(grep -Eo '[0-9\.]+' /etc/system-release)
echo "SYSTEM_RELEASE_VER: ${SYSTEM_RELEASE_VER}"
export SYSTEM_RELEASE_VER=$SYSTEM_RELEASE_VER

echo "TARGETPLATFORM: ${TARGETPLATFORM}"
echo "USER_HOME_DIR: ${USER_HOME_DIR}"
echo "TARGETARCH: ${TARGETARCH}"
echo "TARGETOS: ${TARGETOS}"
echo "RUNTIME: ${RUNTIME}"
echo "RUNTIMEVER: ${RUNTIMEVER}"
echo "SDK: ${SDK}"
echo "SYSTEM_RELEASE_VER: ${SYSTEM_RELEASE_VER}"

exec "${HOME}/scripts/create_net_layer.sh"
