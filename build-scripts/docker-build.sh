#!/bin/bash

# Set value for varaibles, if they don't exist.
: ${DOCKER_ENV:=local}
: ${BUILD_NUMBER:=1}

echo BUILD_NUMBER: $BUILD_NUMBER
echo DOCKER_ENV: $DOCKER_ENV


if [ -n "$GIT_DEPLOY_KEY_FILE" ]; then
  # Do Jenkins-specific actions
  rm -rf keys || echo "keys not present"
  mkdir keys || echo "keys already exist"
  cp $GIT_DEPLOY_KEY_FILE keys/id_rsa
  #cp ${GIT_DEPLOY_KEY} keys/id_rsa
  #cp ${EYAML_PRIVATE_KEY} keys/
  #cp ${EYAML_PUBLIC_KEY} keys/
fi

echo $BUILD_NUMBER > version

docker build --build-arg DOCKER_ENV=${DOCKER_ENV} -t dtr.cucloud.net/cs/petshop-${DOCKER_ENV} .
docker push dtr.cucloud.net/cs/petshop-${DOCKER_ENV}:latest
docker tag dtr.cucloud.net/cs/petshop-${DOCKER_ENV}:latest dtr.cucloud.net/cs/petshop-${DOCKER_ENV}:v_${BUILD_NUMBER}
docker push dtr.cucloud.net/cs/petshop-${DOCKER_ENV}:v_${BUILD_NUMBER}
docker rmi dtr.cucloud.net/cs/petshop-${DOCKER_ENV}:v_${BUILD_NUMBER}
#docker images | grep petshop

if [ -n "$JENKINS_HOME" ]; then
  rm -rf keys || echo "keys have been deleted"
fi