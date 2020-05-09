#! /bin/bash

DEPLOY_DIR=./services
SERVICE=$1
ENV=$2
SERVICE_PATH=${DEPLOY_DIR}/${SERVICE}
SERVICE_ENV_PATH=${SERVICE_PATH}/${ENV}

kpt pkg update $SERVICE_PATH --strategy resource-merge

TAG=$(cat $SERVICE_PATH/Kptfile | grep commit | awk '{print $2}')

echo ""
echo "Deploying ${SERVICE_ENV_PATH} version ${TAG}"
echo ""

kpt cfg set $SERVICE_ENV_PATH tag $TAG

