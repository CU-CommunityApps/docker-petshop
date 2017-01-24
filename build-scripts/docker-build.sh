#!/bin/bash

# Build and store the docker image for the applicaiton.
# This script is written to work both in Jenkins, and on a local workstation.

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
  #cp $EYAML_PRIVATE_KEY keys/
  #cp $EYAML_PUBLIC_KEY keys/
else
  # Do local workstation-specific actions

  # TODO: Improve flexibilty by looking at AWS_DEFULAT_PROFILE and/or ~/.aws/credentials file.
  if [ -z "$AWS_ACCESS_KEY_ID" ]; then
    echo "ERROR: For a local build, AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY must be present in environment."
    exit 1
  fi
  AWS_CREDS="--build-arg AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID --build-arg AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY"
  echo "Using AWS credentials from environment variables for Docker build. AWS_ACCESS_KEY_ID: $AWS_ACCESS_KEY_ID"
fi

# Break the Docker build cache
date > version

DOCKER_IMAGE=dtr.cucloud.net/cs/$APP_NAME-$DOCKER_ENV

docker build \
  --build-arg DOCKER_ENV=$DOCKER_ENV \
  --build-arg BUILD_NUMBER=$BUILD_NUMBER \
  --build-arg APP_NAME=$APP_NAME \
  $AWS_CREDS \
  -t $DOCKER_IMAGE .
docker push $DOCKER_IMAGE:latest
docker tag $DOCKER_IMAGE:latest $DOCKER_IMAGE:v_$BUILD_NUMBER
docker push $DOCKER_IMAGE:v_$BUILD_NUMBER

if [ -n "$GIT_DEPLOY_KEY_FILE" ]; then
  rm -rf keys || echo "keys have been deleted"
fi