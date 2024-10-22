#!/bin/bash

#NOTE: to use this script and generated playground
#     make sure you have executed ~/scripts/create...layer..sh (e.g. create_layer_net8_linux_amd64.sh)
#     at least once per shell session
#     to get all deps in place!

#echo env
echo "TARGETPLATFORM: ${TARGETPLATFORM}"
echo "USER_HOME_DIR: ${USER_HOME_DIR}"
echo "TARGETARCH: ${TARGETARCH}"
echo "TARGETOS: ${TARGETOS}"
echo "RUNTIME: ${RUNTIME}"
echo "RUNTIMEVER: ${RUNTIMEVER}"
echo "SDK: ${SDK}"
echo "SYSTEM_RELEASE_VER: ${SYSTEM_RELEASE_VER}"

#set home directory
if [[ -z "${USER_HOME_DIR}" ]]; then
  USER_HOME_DIR="/root"
else
  USER_HOME_DIR="${USER_HOME_DIR}"
fi

echo -e "\n***************** Preparing: PLAYGROUND *****************"

# it was already buit in create_net_layer, one may uncomment it to re-complile modified bridge for local testing
#${USER_HOME_DIR}/Snapper.Runtime.Delegator/build.sh
# Is a part of build.sh now
# rhomes=$(/opt/bin/dotnet --info | sed -nr "s/^.*Microsoft.*App\s([0-9.]+)\s\[(.*)]/\2\/\1/p")
# while IFS= read -r dir; do
#     cp -v /root/Snapper.Runtime.Delegator/target/{Snapper.Runtime*,Amazon*} ${dir}/
# done <<< "$rhomes"

#${USER_HOME_DIR}/snapper4net/build.sh
# Is a part of build.sh now
# cp -v /root/snapper4net/target/snapper4* /opt/bin/

mkdir -p /var
mkdir -p /var/task

pushd ${USER_HOME_DIR}/SnappedNetLambdaTest
./build.sh
popd

pushd ${USER_HOME_DIR}/SnappedAspLambdaTest
./build.sh
popd

echo "\n............ exporting env ...................."

#export env for shell use
export PATH=${PATH}:/opt/net
export LD_LIBRARY_PATH=/opt/icu
#will be set by wrapper: export _HANDLER="SnappedNetLambdaTest::SnappedNetLambdaTest.Function::FunctionHandler"
export AWS_EXECUTION_ENV="AWS_Lambda_java21"
export LAMBDA_TASK_ROOT="/var/task"

. /opt/snapper4net_export.sh

if ! [[ -v "${LD_LIBRARY_PATH}" ]]; then
  export LD_LIBRARY_PATH="/var/lang/lib:/lib64:/usr/lib64:/var/runtime:/var/runtime/lib:/var/task:/var/task/lib:/opt/lib"
else 
  export LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/var/task/lib:/opt/lib"
fi

#export SNAPPER_USE_DELEGATOR=true

echo "Done."


