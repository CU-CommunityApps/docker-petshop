#!/bin/bash

# This script does final setup of the container
# and launches the main container process.

#### Run Puppet at container launch. ####

# Primarily, this launch puppet manifest does container configuration that
# we delayed until launch so that secrets are not plain text inside
# the Docker image.

# Get the Puppet environment value from where we stashed it.
PUPPET_ENV=`cat /tmp/puppet_environment`
echo "Using PUPPET_ENV: $PUPPET_ENV"
puppet apply --verbose --modulepath=/modules \
  --hiera_config=/modules/petshop/hiera.yaml \
  --environment=$PUPPET_ENV -e "class { 'petshop::launch': }"

# Cleanup puppet, like the Dockerfile used to.
#rm -rf /modules
#rm -rf /Puppetfile*

# Launch our main process.
exec /usr/sbin/nginx -c /etc/nginx/nginx.conf