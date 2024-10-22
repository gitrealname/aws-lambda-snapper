#!/bin/bash

SCRIPT_DIR=$(dirname "$0")
cd ${SCRIPT_DIR}

mkdir -p ./target

echo "------------------------------< Building Snapper.Runtime.Delegator >-------------------------------"

dotnet build -c Release -f "${RUNTIME}${RUNTIMEVER}.0" ${SCRIPT_DIR}/Snapper.Runtime.Delegator.csproj --output ${SCRIPT_DIR}/target

#keep playground up to date
if [ -f /opt/bin/dotnet ]; then 
    rhomes=$(/opt/bin/dotnet --info | sed -nr "s/^.*Microsoft.*App\s([0-9.]+)\s\[(.*)]/\2\/\1/p")
    echo -e "\n***************** Info: runtime locations *****************"
    while IFS= read -r dir; do
        echo "${dir}"
    done <<< "$rhomes"

    while IFS= read -r dir; do
        cp ${SCRIPT_DIR}/target/Snapper.Runtime.Delegator.* ${dir}/
    done <<< "$rhomes"

    #store runtime homes into snapper4net_export.sh for export as DOTNET_ADDITIONAL_DEPS
    tmp=()
    while IFS= read -r dir; do
            tmp+=($dir)
    done <<< "$rhomes"    
    tmp1=$(IFS=":" ; echo "${tmp[*]}")

    echo "export DOTNET_ADDITIONAL_DEPS=${tmp1}"

    echo "export DOTNET_ADDITIONAL_DEPS=${tmp1}" >> /opt/snapper4net_export.sh
    echo >> /opt/snapper4net_export.sh

    # echo "export DOTNET_ADDITIONAL_DEPS=${tmp1}" >> /root/scripts/snapper4net_export.sh
    # echo >> /root/scripts/snapper4net_export.sh

fi

echo "Done."
