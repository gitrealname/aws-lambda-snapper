#!/bin/bash

echo "------------------------------< Building SnappedNetLambdaTest >-------------------------------"

SCRIPT_DIR=$(dirname "$0")
cd ${SCRIPT_DIR}

echo "--- script directory: ${SCRIPT_DIR} ---"

sam build

echo "------- copy files into /var/task ------------"
mkdir -p /var/task
echo "cp -vrf ${SCRIPT_DIR}/.aws-sam/build/SnappedNetLambdaTestFunction/* /var/task/"
cp -vrf ./.aws-sam/build/SnappedNetLambdaTestFunction/* /var/task/
