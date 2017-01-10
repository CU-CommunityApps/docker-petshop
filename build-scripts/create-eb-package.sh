#!/bin/bash

# This script is run by Jenkins to create an EB build package.
# Ideally it could also be used during local development for testing,
# but the "-i" option of the sed command is different on linux vs OS X.

echo PIPELINE BUILD: ${PIPELINE_BUILD:=unset}
echo GIT_BRANCH: ${GIT_BRANCH:=unset}
echo FILESYSTEM: ${FILESYSTEM:=unset}
echo BEANSTALK_ENV: ${BEANSTALK_ENV:=unset}
echo DOCKER_ENV: ${DOCKER_ENV:=unset}

rm -rf build|| echo "build did not exist"
mkdir -p build/.ebextensions
cp .ebextensions/*.config build/.ebextensions/

# overwrite the efs.config file with the templated version
sed "s/FILESYSTEM/$FILESYSTEM/g" < .ebextensions-templates/efs.config > build/.ebextensions/efs.config
sed "s/BUILD_NUMBER/$PIPELINE_BUILD/g" < Dockerrun.aws.v2.template.json > build/Dockerrun.aws.json

# This will cause an error on OS X. Use this instead:
# sed -i '.tmp' "s/ENVIRONMENT/$environment/g" build/Dockerrun.aws.json
sed -i "s/DOCKER_ENV/$DOCKER_ENV/g" build/Dockerrun.aws.json

ls -al build build/.ebextensions
cat build/Dockerrun.aws.json