FROM dtr.cucloud.net/cs/awscli

# build argument for environment
ARG DOCKER_ENV=local
ARG BUILD_NUMBER=1
ARG APP_NAME=petshop
ARG AWS_ACCESS_KEY_ID
ARG AWS_SECRET_ACCESS_KEY

RUN \
  apt-get update && \
  apt-get install -y nano nginx zip && \
  echo "daemon off;" >> /etc/nginx/nginx.conf

# Setup launch script
COPY container-scripts/launch.sh /root

# Install extra gems, not installed by dtr.cucloud.net/cs/base.
# Required for running our puppet manifests.
RUN \
  gem install aws-sdk -v 2.6.49 && \
  gem install hiera-eyaml-kms -v 0.1

# bust Docker caching
ADD version /tmp/version

# Start setting up EB deployment package in /tmp/build.
# Puppet will finish populating it, and zip it.
COPY .ebextensions/*.config /tmp/build/.ebextensions/

# BEGIN PUPPET CONFIG

WORKDIR /
COPY Puppetfile /
COPY keys/ /keys

RUN \
  mkdir -p /root/.ssh/ && \
  cp /keys/id_rsa /root/.ssh/id_rsa && \
  chmod 400 /root/.ssh/id_rsa && \
  touch /root/.ssh/known_hosts && \
  ssh-keyscan github.com >> /root/.ssh/known_hosts && \
  export FACTER_build_number=${BUILD_NUMBER} && \
  export FACTER_app_name=${APP_NAME} && \
  librarian-puppet install --verbose && \
  puppet apply --verbose --modulepath=/modules \
    --hiera_config=/modules/petshop/hiera.yaml \
    --environment=${DOCKER_ENV} -e "class { 'petshop::app': }" && \
  rm -rf /root/.ssh &&  \
  rm -rf /keys && \
  echo $DOCKER_ENV > /tmp/puppet_environment
# Leave puppet intact for post-launch use at container launch time.
#  rm -rf /modules && \
#  rm -rf /Puppetfile* && \
# END PUPPET CONFIG

EXPOSE 8080

CMD ["/root/launch.sh"]
