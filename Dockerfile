FROM dtr.cucloud.net/cs/base

# build argument for environment
ARG DOCKER_ENV=local

RUN \
  apt-get update && \
  apt-get install -y nginx && \
  echo "daemon off;" >> /etc/nginx/nginx.conf

# bust Docker caching
ADD version /tmp/version

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

CMD ["/usr/sbin/nginx", "-c", "/etc/nginx/nginx.conf"]
