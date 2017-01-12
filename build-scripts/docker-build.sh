#!/bin/bash

# Set value for variables, if they don't exist.
: ${DOCKER_ENV:=local}
: ${BUILD_NUMBER:=1}
: ${APP_NAME:=petshop}

echo DOCKER_ENV: $DOCKER_ENV
echo BUILD_NUMBER: $BUILD_NUMBER
echo APP_NAME: $APP_NAME

if [ -n "$GIT_DEPLOY_KEY_FILE" ]; then
  # Do Jenkins-specific actions
  rm -rf keys || echo "keys not present"
  mkdir keys || echo "keys already exist"
  cp $GIT_DEPLOY_KEY_FILE keys/id_rsa
  #cp $GIT_DEPLOY_KEY keys/id_rsa
  #cp $EYAML_PRIVATE_KEY keys/
  #cp $EYAML_PUBLIC_KEY keys/
fi

echo $BUILD_NUMBER > version

DOCKER_IMAGE=dtr.cucloud.net/cs/$APP_NAME-$DOCKER_ENV

docker build \
  --build-arg DOCKER_ENV=$DOCKER_ENV \
  --build-arg BUILD_NUMBER=$BUILD_NUMBER \
  --build-arg APP_NAME=$APP_NAME \
  -t $DOCKER_IMAGE .
docker push $DOCKER_IMAGE:latest
docker tag $DOCKER_IMAGE:latest $DOCKER_IMAGE:v_$BUILD_NUMBER
docker push $DOCKER_IMAGE:v_$BUILD_NUMBER

if [ -n "$GIT_DEPLOY_KEY_FILE" ]; then
  rm -rf keys || echo "keys have been deleted"
fi