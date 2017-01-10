#!groovy
node {

  echo "------------------------"
  echo "BUILD_NUMBER: ${env.BUILD_NUMBER}"
  // echo "DOCKER_ENV: ${DOCKER_ENV}"
  // echo "BEANSTALK_ENV: ${BEANSTALK_ENV}"
  // echo "FILESYSTEM: ${FILESYSTEM}"
  // echo "GIT_BRANCH: ${GIT_BRANCH}"
  echo "------------------------"

  stage 'Test'
//  build job: 'petshop-puppet-tests', parameters: [ \
//    string(name: 'PIPELINE_BUILD', value: env.BUILD_NUMBER), \
//    string(name: 'GIT_BRANCH', value: GIT_BRANCH) \
//  ]

  stage 'Build'
  sh 'build-scripts/docker-build.sh'
  // build job: 'petshop-docker-build', parameters: [ \
  //   string(name: 'DOCKER_ENV', value: DOCKER_ENV), \
  //   string(name: 'GIT_BRANCH', value: GIT_BRANCH), \
  //   string(name: 'PIPELINE_BUILD', value: env.BUILD_NUMBER) \
  //   ]
}

// Best practices:
// 1. Perform interactive input outside of a node so it won't tie up a node.
// 2. Put a limit on the interaction, after which the job will abort.
stage 'Wait'
if (DOCKER_ENV == 'prod') {
  timeout(time:1, unit:'DAYS') {
    input message:'Approve deployment? Approve or Abort'
  }
}

node {
  stage 'Deploy'
  // build job: 'petshop-beanstalk-deploy', parameters: [ \
  //   string(name: 'DOCKER_ENV', value: DOCKER_ENV), \
  //   string(name: 'FILESYSTEM', value: FILESYSTEM), \
  //   string(name: 'BEANSTALK_ENV', value: BEANSTALK_ENV), \
  //   string(name: 'GIT_BRANCH', value: GIT_BRANCH), \
  //   string(name: 'PIPELINE_BUILD', value: env.BUILD_NUMBER) \
  //   ]

}
