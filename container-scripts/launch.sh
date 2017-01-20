#!/bin/bash

# This script does final setup of the container
# and launches the main container process.

# Descrypt secrets. The /tmp/secrets directory is populated
# by the puppet configuration

# This will decrypt into /tmp/secrets/service.conf
/tmp/secrets/kms-decrypt-files.sh /tmp/secrets/service.conf.encrypted

# Ensure proper owner and permissions for our decrypted file.
chmod 0400 /tmp/secrets/service.conf
chown root:root /tmp/secrets/service.conf

#### Run Puppet at container launch. ####
puppet apply --verbose --modulepath=/modules \
  --hiera_config=/modules/petshop/hiera.yaml \
  --environment=local -e "class { 'petshop::launch': }"

# Cleanup puppet, like the Dockerfile used to.
rm -rf /modules
rm -rf /Puppetfile*

# Launch our main process.
exec /usr/sbin/nginx -c /etc/nginx/nginx.conf