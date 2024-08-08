#!/bin/bash

#echo env
echo "ACTION: ${ACTION}"
echo "USER_HOME_DIR: ${USER_HOME_DIR}"
echo "TARGETARCH: ${TARGETARCH}"
echo "TARGETOS: ${TARGETOS}"

RELEASE_VER=$(grep -Eo '[0-9\.]+' /etc/system-release)
echo "RELEASE_VER: ${RELEASE_VER}"

#set home directory
if [[ -z "${USER_HOME_DIR}" ]]; then
  USER_HOME_DIR="/root"
else
  USER_HOME_DIR="${USER_HOME_DIR}"
fi

#create dnf jail
cd  ${USER_HOME_DIR}
mkdir dnfjail
mkdir dnfjail/etc
mkdir dnfjail/etc/dnf
cp /etc/dnf/dnf.conf ${USER_HOME_DIR}/dnfjail/etc/dnf
echo "#reposdir=" >> ${USER_HOME_DIR}/dnfjail/etc/dnf/dnf.conf
echo "install_weak_deps=False" >> ${USER_HOME_DIR}/dnfjail/etc/dnf/dnf.conf
mkdir ${USER_HOME_DIR}/dnfjail/etc/yum.repos.d
cp /etc/yum.repos.d/* ${USER_HOME_DIR}/dnfjail/etc/yum.repos.d

#jail .net runtime
dnf -c ${USER_HOME_DIR}/dnfjail/etc/dnf/dnf.conf install -y --installroot  ${USER_HOME_DIR}/dnfjail --releasever=${RELEASE_VER} bash dotnet-runtime-8.0

#create layer
mkdir ${USER_HOME_DIR}/layer
mkdir ${USER_HOME_DIR}/output
cp ${USER_HOME_DIR}/layer_scripts/* ${USER_HOME_DIR}/layer
cd ${USER_HOME_DIR}/layer
zip -r ../output/layer_${TARGETOS}_${TARGETARCH}.zip *
cd  ${USER_HOME_DIR}/dnfjail
zip -ru ../output/layer_${TARGETOS}_${TARGETARCH}.zip *

