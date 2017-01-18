#!/bin/bash

# This script does final setup of the container, and launches the main process.

# Descrypt secrets. The /tmp/secrets directory is populated
# by the puppet configuration

# This will decrypt into /tmp/secrets/service.conf
/tmp/secrets/kms-decrypt-files.sh /tmp/secrets/service.conf.encrypted

# Ensure proper owner and permissions for our decrypted file.
chmod 0400 /tmp/secrets/service.conf
chown root:root /tmp/secrets/service.conf

# Launch our main process.
exec /usr/sbin/nginx -c /etc/nginx/nginx.conf