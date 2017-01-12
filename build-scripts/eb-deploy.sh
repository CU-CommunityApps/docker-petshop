#!/bin/bash

# Set value for variables, if they don't exist.
: ${DOCKER_ENV:=local}
: ${BUILD_NUMBER:=1}
: ${APP_NAME:=petshop}
: ${AWS_ACCOUNT:=225162606092}
: ${AWS_REGION:=us-east-1}

echo DOCKER_ENV: $DOCKER_ENV
echo BUILD_NUMBER: $BUILD_NUMBER
echo APP_NAME: $APP_NAME

#if [ -n "$GIT_DEPLOY_KEY_FILE" ]; then
  # Do Jenkins-specific actions
#fi

DOCKER_IMAGE=dtr.cucloud.net/cs/${APP_NAME}-${DOCKER_ENV}:v_${BUILD_NUMBER}
VERSION_LABEL=${APP_NAME}-${DOCKER_ENV}-${BUILD_NUMBER}
ZIP_FILE=$VERSION_LABEL.zip
S3_BUCKET=elasticbeanstalk-${AWS_REGION}-${AWS_ACCOUNT}

docker run $DOCKER_IMAGE cat /tmp/$ZIP_FILE > $ZIP_FILE

aws s3 cp $ZIP_FILE s3://$S3_BUCKET/${APP_NAME}/$ZIP_FILE

echo "Create application version."
aws elasticbeanstalk create-application-version \
  --application-name ${APP_NAME} \
  --version-label ${VERSION_LABEL} \
  --source-bundle S3Bucket=$S3_BUCKET,S3Key=${APP_NAME}/$ZIP_FILE \
  --process

while [ "$RESULT" != "PROCESSED" ]; do
  RESULT=`aws elasticbeanstalk describe-application-versions --application-name ${APP_NAME} --version-labels ${VERSION_LABEL} --query 'ApplicationVersions[0].Status' --output text`
  echo $RESULT
done

aws elasticbeanstalk update-environment \
   --application-name ${APP_NAME} \
   --environment-name ${APP_NAME}-${DOCKER_ENV} \
   --version-label ${VERSION_LABEL}

# Clean up
docker rmi $DOCKER_IMAGE

