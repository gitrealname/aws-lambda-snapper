#!/bin/bash
# OBSOLETE: There is no need to have Snapper.Runtime.Delegator 
originalIFS="$IFS"

#test
echo 
if ! [ -n "${AWS_LAMBDA_RUNTIME_API}" ]; then
  echo "SNAPPER-WRAPPER: TEST MODE"
  AWS_EXECUTION_ENV="AWS_Lambda_java21"
  LAMBDA_TASK_ROOT="/var/task"
  _HANDLER=SnappedNetLambdaTest::SnappedNetLambdaTest.Function::FunctionHandler
fi

#grab args
args=("$@")

#detect execution env (AWS_EXECUTION_ENV) and do nothing unless it is like 'AWS_Lambda_java*' 
echo "SNAPPER-WRAPPER: validating execution environment..."

if [[ $AWS_EXECUTION_ENV != AWS_Lambda_java* ]]; then
  echo "SNAPPER-WRAPPER: execution environment is not Java. Executing normally."
  exec "${args[@]}"
  exit 0
fi

#run export script
. /opt/snapper4net_export.sh

#deligating to task bootstrap.sh if exists
if [ -f "${LAMBDA_TASK_ROOT}/bootstrap.sh" ]; then
  echo "SNAPPER-WRAPPER: executing /bin/bash ${LAMBDA_TASK_ROOT}/bootstrap.sh ${args[@]}..."
  exec "/bin/bash" "${LAMBDA_TASK_ROOT}/bootstrap.sh" "${args[@]}"
fi

#detect dotnet framework type lambda depends on
echo "SNAPPER-WRAPPER: detecting lambda's framework..."
if [ -f /tmp/sdk_location ]; then
  loc=$(cat "/tmp/sdk_location")
  echo "SNAPPER-WRAPPER: sdk location (from cache): ${loc}"
else
  #build path to handlers ...runtimeconfig.json
  IFS="::"
  set -- $_HANDLER
  cfg_file="${LAMBDA_TASK_ROOT}/${1}.runtimeconfig.json"
  IFS=$originalIFS
  if ! [ -f $cfg_file ]; then
    echo "SNAPPER-WRAPPER: ERROR: file ${cfg_file} not found. Terminating..."
    exit 1
  fi
  #flatten file
  flat_content=$(tr -d '\n\r\t ' < $cfg_file)
  #search for runtimeOptions....framework...name...Microsoft.NETCore.XXX
  framework=$(echo $flat_content | sed -nr  's/^.*runtimeOptions.*?framework.*?name.*?(Microsoft[^"]*).*$/\1/p')
  echo "SNAPPER-WRAPPER: lambda framework: ${framework}"
  #run dotnet to extract runtime location
  rhomes=$(/opt/bin/dotnet --info | sed -nr "s/^.*Microsoft.*App\s([0-9.]+)\s\[(.*)]/\2\/\1/p")
  while IFS= read -r i; do
    if [[ $i == *"${framework}"* ]]; then
      loc=$i
      break
    fi
  done <<< "$rhomes"
  if [ -z ${loc} ]; then 
    echo "SNAPPER-WRAPPER: ERROR: sdk location not found. Terminating...";
    exit 1
  fi
  echo "SNAPPER-WRAPPER: sdk location ${loc}"
  #caching for quick access
  echo $loc > /tmp/sdk_location
fi

#setting env and starting
export NET_RUNTIME_PATH=$loc
export LAMBDA_RUNTIME_DIR=$loc
export DOTNET_ROOT=/opt/bin
export AWS_EXECUTION_ENV
export LAMBDA_TASK_ROOT
export _HANDLER

if ! [[ -v "${LD_LIBRARY_PATH}" ]]; then
  export LD_LIBRARY_PATH="${loc}:/var/lang/lib:/lib64:/usr/lib64:/var/runtime:/var/runtime/lib:/var/task:/var/task/lib:/opt/lib"
else 
  export LD_LIBRARY_PATH="${loc}:${LD_LIBRARY_PATH}"
fi

cmd="/opt/bin/snapper4net"
echo "SNAPPER-WRAPPER: starting(${cmd})..."
exec "${cmd}"
