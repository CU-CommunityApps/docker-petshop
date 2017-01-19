#!groovy

// This file defines a build pipeline for the application in Jenkins.

node {

  echo "------------------------"
  echo "BUILD_NUMBER: ${env.BUILD_NUMBER}" // This is the Jenkins job build number stored as env variable.
  echo "DOCKER_ENV: ${DOCKER_ENV}"
  echo "APP_NAME: ${APP_NAME}"
  echo "BEANSTALK_ENV: ${APP_NAME}-${DOCKER_ENV}"
  echo "GIT_BRANCH: ${GIT_BRANCH}"
  echo "------------------------"


  stage 'Build'

  // This credentialsId is for the cujenkins RO user in the CU-CommunityApps git organization.
  // The  credentialsId is specific to the Jenkins instance.
  git branch: "${GIT_BRANCH}", changelog: false, credentialsId: 'b0255d81-2321-4bb3-8d52-2ae1790e5f49', poll: false, url: 'git@github.com:CU-CommunityApps/docker-petshop.git'

  // Convert local Groovy vars into environment variables.
  withEnv(["DOCKER_ENV=${DOCKER_ENV}", "APP_NAME=${APP_NAME}"]) {
    // This credentialsId is the private key file for the deploy key configured
    // for the puppet-petshop repo in github.
    withCredentials([file(credentialsId: 'github-puppet-petshop-deploy', variable: 'GIT_DEPLOY_KEY_FILE')]) {
        sh "./build-scripts/docker-build.sh"
    }
  }

  stage 'Deploy'

  withEnv(["DOCKER_ENV=${DOCKER_ENV}", "APP_NAME=${APP_NAME}"]) {
    sh "./build-scripts/eb-deploy.sh"
  }
}



