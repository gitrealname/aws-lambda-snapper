#!/bin/bash

SCRIPT_DIR=$(dirname "$0")
cd ${SCRIPT_DIR}

mkdir -p ./target

echo "------------------------------< Building snapper4net >-------------------------------"

CPP_DIR="${SCRIPT_DIR}"
mkdir -p ${CPP_DIR}/obj

NET_HOST_DIR=$(dotnet msbuild ${CPP_DIR}/helper.csproj -t:GetNetHostDir | tail -1 | sed 's/ //g')
echo "NET_HOST_DIR: ${NET_HOST_DIR}"

#compile
g++ -c -fPIC -D LINUX -I"${NET_HOST_DIR}" ${CPP_DIR}/snapper4net.cpp -o ${CPP_DIR}/obj/snapper4net.o
g++ -c -fPIC -D LINUX -I"${NET_HOST_DIR}" ${CPP_DIR}/main.cpp -o ${CPP_DIR}/obj/main.o

#link
g++ -fPIC -lc -L"${NET_HOST_DIR}" -lnethost -W --disable-new-dtags -o ${SCRIPT_DIR}/target/snapper4net ${CPP_DIR}/obj/main.o ${CPP_DIR}/obj/snapper4net.o

cp ${NET_HOST_DIR}/libnethost.so  ${SCRIPT_DIR}/target/

#keep playground up-to date
mkdir -p /opt
mkdir -p /opt/bin
mkdir -p /opt/lib
cp ${SCRIPT_DIR}/target/snapper4net /opt/bin/
cp ${SCRIPT_DIR}/target/lib* /opt/lib/
cp ${SCRIPT_DIR}/snapper4net*.sh /opt

echo "Done."
