#!/bin/bash

#prep destination
mkdir -p ${USER_HOME_DIR}/output
rm -rf /opt/*

#create dnf jail
echo -e "\n***************** Preparing: dnf jail *****************"
cd  ${USER_HOME_DIR}
mkdir dnfjail
mkdir dnfjail/etc
mkdir dnfjail/etc/dnf
cp /etc/dnf/dnf.conf ${USER_HOME_DIR}/dnfjail/etc/dnf
echo "#reposdir=" >> ${USER_HOME_DIR}/dnfjail/etc/dnf/dnf.conf
echo "install_weak_deps=False" >> ${USER_HOME_DIR}/dnfjail/etc/dnf/dnf.conf
mkdir ${USER_HOME_DIR}/dnfjail/etc/yum.repos.d
cp /etc/yum.repos.d/* ${USER_HOME_DIR}/dnfjail/etc/yum.repos.d
mkdir /opt 2>/dev/null
echo "Done."

#install icu (internalization support. .net cannot work without it) (skip if exists)
echo -e "\n***************** Installing: ICU *****************"
if ! ls  /opt/lib/libicu/* 1> /dev/null 2>&1; then 
  echo "installing icu..."
  dnf -c ${USER_HOME_DIR}/dnfjail/etc/dnf/dnf.conf install -y --installroot  ${USER_HOME_DIR}/dnfjail --releasever=${SYSTEM_RELEASE_VER} icu
  mkdir /opt/lib
  cp /root/dnfjail/lib64/libicu* /opt/lib
fi
echo "Done."

#install dotnet (skip if exists)
echo -e "\n***************** Installing: dotnet *****************"
if ! [ -f /opt/bin/dotnet ]; then 
  ${USER_HOME_DIR}/scripts/dotnet-install.sh --runtime ${SDK} --install-dir /opt/bin --no-path
fi
echo "Done."

#install/copying utils that may be need by other "smart" layers/apps
echo -e "\n***************** Installing/copy: "must have" Utils for 'smart' layers/apps *****************"
  ldd /usr/bin/unzip | awk 'NF == 4 { system("cp " $3 " /opt/lib/") }'
  cp -v /usr/bin/unzip /opt/bin

  ldd /usr/bin/gzip | awk 'NF == 4 { system("cp " $3 " /opt/lib/") }'
  cp -v /usr/bin/gzip /opt/bin

  ldd /usr/bin/tar | awk 'NF == 4 { system("cp " $3 " /opt/lib/") }'
  cp -v /usr/bin/tar /opt/bin

  ldd /usr/bin/cpio | awk 'NF == 4 { system("cp " $3 " /opt/lib/") }'
  cp -v /usr/bin/cpio /opt/bin

  ldd /usr/bin/rpm | awk 'NF == 4 { system("cp " $3 " /opt/lib/") }'
  cp -v /usr/bin/rpm /opt/bin

  ldd /usr/bin/awk | awk 'NF == 4 { system("cp " $3 " /opt/lib/") }'
  cp -v /usr/bin/awk /opt/bin

  ldd /usr/sbin/sysctl | awk 'NF == 4 { system("cp " $3 " /opt/lib/") }'
  cp -v /usr/sbin/sysctl /opt/bin

  #remove which will always be given/provided by the host
  rm  -f /opt/lib/ld-linux-x86-64.so.2 /opt/lib/linux-vdso.so.1
echo "Done."


#prep for .net builds and publishing
#get net runtimes location artifacts
# Moved into Delegator build.sh
# rhomes=$(/opt/bin/dotnet --info | sed -nr "s/^.*Microsoft.*App\s([0-9.]+)\s\[(.*)]/\2\/\1/p")
# echo -e "\n***************** Info: runtime locations *****************"
# while IFS= read -r dir; do
#     echo "${dir}"
# done <<< "$rhomes"
# echo "Done."

#build snapper4net
#echo -e "\n***************** Installing: snapper4net *****************"
${USER_HOME_DIR}/snapper4net/build.sh
#moved to build.sh
# cp ${USER_HOME_DIR}/snapper4net/target/snapper4net /opt/bin/
# cp ${USER_HOME_DIR}/snapper4net/target/lib* /opt/lib/
# echo "Done."

#build Snapper.Runtime.Delegator
#echo -e "\n***************** Installing: Snapper.Runtime.Delegator *****************"
${USER_HOME_DIR}/Snapper.Runtime.Delegator/build.sh
# Moved into build.sh
# while IFS= read -r dir; do
#     cp ${USER_HOME_DIR}/Snapper.Runtime.Delegator/target/Snapper.Runtime.Delegator.* ${dir}/
# done <<< "$rhomes"
# echo "Done."

#build and copy AWS runtime deps
echo -e "\n***************** Installing: Amazon runtime deps *****************"
${USER_HOME_DIR}/get-aws-net-runtime/build.sh
# Moved into build.sh
# rhomes=$(/opt/bin/dotnet --info | sed -nr "s/^.*Microsoft.*App\s([0-9.]+)\s\[(.*)]/\2\/\1/p")
# echo -e "    found net runtimes:"
# while IFS= read -r dir; do
#     echo "\t${dir}"
# done <<< "$rhomes"

# while IFS= read -r dir; do
#     cp ${USER_HOME_DIR}/get-aws-net-runtime/target/Amazon.* ${dir}/
# done <<< "$rhomes"
# echo "Done."

#create layer
echo -e "\n***************** Creating: layer *****************"
cd  /opt
cp -v ${USER_HOME_DIR}/layer_scripts/* /opt/
zip -ru ${USER_HOME_DIR}/output/snapper_layer_${RUNTIME}${RUNTIMEVER}_${SDK}_${TARGETOS}_${TARGETARCH}.zip *
echo "Done."

#optional for local testing.
echo -e "\n***************** setup_net_playgound *****************"
. ${USER_HOME_DIR}/scripts/setup_net_playgound.sh
