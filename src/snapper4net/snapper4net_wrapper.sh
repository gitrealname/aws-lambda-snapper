#!/bin/bash
originalIFS="$IFS"

#NOTE: Clean up is pending. As lots of logic here is obsolete and is not needed anymore (having that we don't use Runtime delegator anymore and use dotnet directly)

#test
echo 
if ! [ -n "${AWS_LAMBDA_RUNTIME_API}" ]; then
  echo "SNAPPER-WRAPPER: TEST MODE"
  AWS_EXECUTION_ENV="AWS_Lambda_java21"
  LAMBDA_TASK_ROOT="/var/task"
  _HANDLER=SnappedAspLambdaTest
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

#set vars
#setting env and starting
export DOTNET_ROOT=/opt/bin
DOTNET_BIN="${DOTNET_ROOT}/dotnet"
DOTNET_EXEC="exec"
DOTNET_ARGS=()
EXECUTABLE_BINARY_EXIST=false
LAMBDA_HANDLER="${_HANDLER}"
HANDLER_COL_INDEX=$(expr index "${LAMBDA_HANDLER}" ":")
RUNTIME_SUPPORT_DLL="Amazon.Lambda.RuntimeSupport.dll"

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

if [[ "${HANDLER_COL_INDEX}" == 0 ]]; then 
  EXECUTABLE_ASSEMBLY="${LAMBDA_TASK_ROOT}/${LAMBDA_HANDLER}"
  EXECUTABLE_BINARY="${LAMBDA_TASK_ROOT}/${LAMBDA_HANDLER}"
  if [[ "${EXECUTABLE_ASSEMBLY}" != *.dll ]]; then
    EXECUTABLE_ASSEMBLY="${EXECUTABLE_ASSEMBLY}.dll"
  fi
  if [[ -f "${EXECUTABLE_ASSEMBLY}" ]]; then
    DOTNET_ARGS+=("${EXECUTABLE_ASSEMBLY}")
  elif [[ -f "${EXECUTABLE_BINARY}" ]]; then
    EXECUTABLE_BINARY_EXIST=true
  else
    echo "SNAPPER-WRAPPER: Error: executable assembly ${EXECUTABLE_ASSEMBLY} or binary ${EXECUTABLE_BINARY} not found." 1>&2
    exit 104
  fi
# Use external runtime
else
  if [ -n "${LAMBDA_DOTNET_MAIN_ASSEMBLY}" ]; then
    if [[ "${LAMBDA_DOTNET_MAIN_ASSEMBLY}" == *.dll ]]; then
      ASSEMBLY_NAME="${LAMBDA_DOTNET_MAIN_ASSEMBLY::-4}"
    else
      ASSEMBLY_NAME="${LAMBDA_DOTNET_MAIN_ASSEMBLY}"
    fi
  else
    ASSEMBLY_NAME="${LAMBDA_HANDLER::${HANDLER_COL_INDEX}-1}"
  fi

  DEPS_FILE="${LAMBDA_TASK_ROOT}/${ASSEMBLY_NAME}.deps.json"
  if ! [ -f "${DEPS_FILE}" ]; then
    DEPS_FILES=( "${LAMBDA_TASK_ROOT}"/*.deps.json )

    # Check if there were any matches to the *.deps.json glob, and that the glob was resolved
    # This makes the matching independent from the global `nullopt` shopt's value (https://www.gnu.org/software/bash/manual/html_node/The-Shopt-Builtin.html)
    if [ "${#DEPS_FILES[@]}" -ne 1 ] || echo "${DEPS_FILES[0]}" | grep -q -F '*'; then
      echo "SNAPPER-WRAPPER: Error: .NET binaries for Lambda function are not correctly installed in the ${LAMBDA_TASK_ROOT} directory of the image when the image was built. The ${LAMBDA_TASK_ROOT} directory is missing the required .deps.json file." 1>&2
      exit 105
    fi
    DEPS_FILE="${DEPS_FILES[0]}"
  fi

  RUNTIMECONFIG_FILE="${LAMBDA_TASK_ROOT}/${ASSEMBLY_NAME}.runtimeconfig.json"
  if ! [ -f "${RUNTIMECONFIG_FILE}" ]; then
    RUNTIMECONFIG_FILES=( "${LAMBDA_TASK_ROOT}"/*.runtimeconfig.json )

    # Check if there were any matches to the *.runtimeconfig.json glob, and that the glob was resolved
    # This makes the matching independent from the global `nullopt` shopt's value (https://www.gnu.org/software/bash/manual/html_node/The-Shopt-Builtin.html)
    if [ "${#RUNTIMECONFIG_FILES[@]}" -ne 1 ] || echo "${RUNTIMECONFIG_FILES[0]}" | grep -q -F '*'; then
      echo "SNAPPER-WRAPPER: Error: .NET binaries for Lambda function are not correctly installed in the ${LAMBDA_TASK_ROOT} directory of the image when the image was built. The ${LAMBDA_TASK_ROOT} directory is missing the required .runtimeconfig.json file." 1>&2
      exit 106
    fi
    RUNTIMECONFIG_FILE="${RUNTIMECONFIG_FILES[0]}"
  fi

  # Find location of Amazon.Lambda.RuntimeSupport.dll
  if [ -f /tmp/sdk_location ]; then
    loc=$(cat "/tmp/sdk_location")
    echo "SNAPPER-WRAPPER: sdk location (from cache): ${loc}"
  else
    flat_content=$(tr -d '\n\r\t ' < $RUNTIMECONFIG_FILE)
    #search for runtimeOptions....framework...name...Microsoft.NETCore.XXX
    framework=$(echo $flat_content | sed -nr  's/^.*runtimeOptions.*?framework.*?name.*?(Microsoft[^"]*).*$/\1/p')
    echo "SNAPPER-WRAPPER: lambda framework: ${framework}"
    #run dotnet to extract runtime location
    rhomes=$( ${DOTNET_BIN} --info | sed -nr "s/^.*Microsoft.*App\s([0-9.]+)\s\[(.*)]/\2\/\1/p")
    while IFS= read -r i; do
      if [[ $i == *"${framework}"* ]]; then
        loc=$i
        break
      fi
    done <<< "$rhomes"
    if [ -z ${loc} ]; then 
      echo "SNAPPER-WRAPPER: ERROR: sdk location not found. Terminating..." 1>&2
      exit 201
    fi
    echo "SNAPPER-WRAPPER: sdk location ${loc}"
    #caching for quick access
    echo $loc > /tmp/sdk_location
  fi
  # Build runtime support dll name
  RUNTIME_SUPPORT_DLL="${loc}/${RUNTIME_SUPPORT_DLL}"
  if ! [ -f $RUNTIME_SUPPORT_DLL ]; then
    echo "SNAPPER-WRAPPER: Error: ${RUNTIME_SUPPORT_DLL} not found" 1>&2
    exit 202
  fi
  echo "SNAPPER-WRAPPER: Runtime DLL: ${RUNTIME_SUPPORT_DLL}"

  # Build Args
  DOTNET_ARGS+=("--depsfile" "${DEPS_FILE}"
                "--runtimeconfig" "${RUNTIMECONFIG_FILE}"
                "${RUNTIME_SUPPORT_DLL}" "${LAMBDA_HANDLER}")
fi

if ! [[ -v "${LD_LIBRARY_PATH}" ]]; then
  export LD_LIBRARY_PATH="/var/lang/lib:/lib64:/usr/lib64:/var/runtime:/var/runtime/lib:/var/task:/var/task/lib:/opt/lib"
else 
  export LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/var/task/lib:/opt/lib"
fi

# Start
if ! [ -z ${SNAPPER_USE_DELEGATOR} ]; then 
  if [[ ${SNAPPER_USE_DELEGATOR} == "true" ]]; then
    cmd="/opt/bin/snapper4net"
    echo "SNAPPER-WRAPPER: Starting Using delegator: (${cmd})..."
    exec "${cmd}"
  fi
fi

#delegating to task's bootstrap.sh if exists
if [ -n "${AWS_LAMBDA_RUNTIME_API}" ]; then
    if [ -f "${LAMBDA_TASK_ROOT}/bootstrap.sh" ]; then
      echo "SNAPPER-WRAPPER: copying ${LAMBDA_TASK_ROOT}/bootstrap.sh --> /tmp"
      cp -v ${LAMBDA_TASK_ROOT}/bootstrap.sh /tmp/
      chmod 777 /tmp/bootstrap.sh
      echo "SNAPPER-WRAPPER: executing: . /tmp/bootstrap.sh ${args[@]}..."
      . /tmp/bootstrap.sh ${args[@]}
    fi
fi

if [ ${EXECUTABLE_BINARY_EXIST} = true ]; then
  echo "SNAPPER-WRAPPER: Starting Binary: ${EXECUTABLE_BINARY}..."
  exec "${EXECUTABLE_BINARY}"
else
  echo "SNAPPER-WRAPPER: Starting: '${DOTNET_BIN} ${DOTNET_EXEC} ${DOTNET_ARGS[@]}'..."
  exec "${DOTNET_BIN}" "${DOTNET_EXEC}" "${DOTNET_ARGS[@]}"
fi
