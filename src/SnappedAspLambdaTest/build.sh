#!/bin/bash

echo "------------------------------< Building SnappedAspLambdaTest >-------------------------------"

SCRIPT_DIR=$(dirname "$0")
cd ${SCRIPT_DIR}

echo "--- script directory: ${SCRIPT_DIR} ---"

sam build

echo "------- copy files into /var/task ------------"
mkdir -p /var/task
echo "cp -vrf ${SCRIPT_DIR}/.aws-sam/build/SnappedAspLambdaTestFunction/* /var/task/"
cp -vrf ./.aws-sam/build/SnappedAspLambdaTestFunction/* /var/task/
