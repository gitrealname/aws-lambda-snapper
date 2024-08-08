echo "------------------------------< Building GET AWS net runtime >-------------------------------"

SCRIPT_DIR=$(dirname "$0")
cd ${SCRIPT_DIR}

mkdir -p ./target

# complie
dotnet build -f "net8.0" -c Release ${SCRIPT_DIR}/Get.Aws.Net.Runtime.csproj --output ${SCRIPT_DIR}/target

#deploy
rhomes=$(/opt/bin/dotnet --info | sed -nr "s/^.*Microsoft.*App\s([0-9.]+)\s\[(.*)]/\2\/\1/p")
echo -e "Found .NET Runtimes:"
while IFS= read -r dir; do
    echo "    ${dir}"
done <<< "$rhomes"

while IFS= read -r dir; do
    cp ${SCRIPT_DIR}/target/Amazon.* ${dir}/
done <<< "$rhomes"

echo "Done."
