#!groovy

node {

  echo "------------------------"
  echo "BUILD_NUMBER: ${env.BUILD_NUMBER}"
  echo "DOCKER_ENV: ${DOCKER_ENV}"
  echo "APP_NAME: ${APP_NAME}"

  // echo "BEANSTALK_ENV: ${BEANSTALK_ENV}"
  // echo "FILESYSTEM: ${FILESYSTEM}"
  // echo "GIT_BRANCH: ${GIT_BRANCH}"
  echo "------------------------"


  stage 'Build'

  git changelog: false, credentialsId: 'b0255d81-2321-4bb3-8d52-2ae1790e5f49', poll: false, url: 'git@github.com:CU-CommunityApps/docker-petshop.git'
  // sh 'ls -al /var/jenkins_home/keys'
  sh 'ls -al'

  withEnv(["DOCKER_ENV=${DOCKER_ENV}", "APP_NAME=${APP_NAME}"]) {
    withCredentials([file(credentialsId: 'github-puppet-petshop-deploy', variable: 'GIT_DEPLOY_KEY_FILE')]) {
        sh "./build-scripts/docker-build.sh"
    }
  }

  stage 'Deploy'

  withEnv(["DOCKER_ENV=${DOCKER_ENV}", "APP_NAME=${APP_NAME}"]) {
    sh "./build-scripts/eb-deploy.sh"
  }
}



