#!/bin/bash

#print env
echo "------------- (wrapper) ENV -------------"
set
echo "-------------  (wrapper) DONE: ENV -------------"

#print dotnet info

#if test -f /opt/net/dotnet; then
if test -f /opt/bin/dotnet; then
  echo "------------- (wrapper) .NET info (/opt/net|bin/dotnet --info) -------------"
#   export PATH=${PATH}:/opt/net
#   export LD_LIBRARY_PATH=/opt/icu
#   /opt/net/dotnet --info
#  /opt/net/dotnet --info
  export PATH=${PATH}:/opt/bin
  export LD_LIBRARY_PATH=/opt/lib
  /opt/bin/dotnet --info
  echo "------------- DONE: (wrapper) .NET info (/opt/net|bin/dotnet --info) -------------"
fi

echo "------------- (wrapper) Build-in .NET info (dotnet --info) -------------"
dotnet --info 2>/dev/null
echo "------------- DONE: (wrapper) Build-in .NET info (dotnet --info) -------------"


echo "-------------------------- (wrapper) "
# the path to the interpreter and all of the originally intended arguments
args=("$@")

# echo args
echo "${args[@]}"

# start the runtime with the extra options
exec "${args[@]}"