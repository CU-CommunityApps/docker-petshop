FROM dtr.cucloud.net/cs/awscli

# build argument for environment
ARG DOCKER_ENV=local
ARG BUILD_NUMBER=1
ARG APP_NAME=petshop

RUN \
  apt-get update && \
  apt-get install -y nginx zip && \
  echo "daemon off;" >> /etc/nginx/nginx.conf

# Setup launch script
COPY container-scripts/launch.sh /root

# bust Docker caching
ADD version /tmp/version

# Start setting up EB deployment packagein /tmp/build.
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
    --environment=${DOCKER_ENV} -e "class { 'petshop::app': }" &&\
  rm -rf /modules && \
  rm -rf /Puppetfile* && \
  rm -rf /root/.ssh && \
  rm -rf /keys
# END PUPPET CONFIG

EXPOSE 8080

CMD ["/root/launch.sh"]
