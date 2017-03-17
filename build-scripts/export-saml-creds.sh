
#!/bin/bash
# This script examines the ~/.aws/credentials file and sets standard AWS CLI
# environmnet variables from the values of the [saml] section.
#
# Obtain temporary credentials using Cornell SSO:
# $ docker run -it --rm -v ~/.aws:/root/.aws dtr.cucloud.net/cs/samlapi
#
# Export the temporary credentials into the current shell
# $ eval $(./export-saml-creds.sh)
#
# Execute the build, passing the temporary credentials.
# $ docker build --build-arg AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID --build-arg AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY --build-arg AWS_SESSION_TOKEN=$AWS_SESSION_TOKEN --rm --no-cache .

AWS_CREDENTIALS_FILE=~/.aws/credentials

# Where is the [saml] section?
SAML_START=`grep -n -F '[saml]' $AWS_CREDENTIALS_FILE | cut -f1 -d:`

# transform the properties into export commands
tail -n+$SAML_START $AWS_CREDENTIALS_FILE | head -n6 | sed '/saml/d' | sed '/output/d' | sed 's/aws_session_token = /export AWS_SESSION_TOKEN=/' | sed 's/aws_access_key_id = /export AWS_ACCESS_KEY_ID=/' | sed 's/aws_secret_access_key = /export AWS_SECRET_ACCESS_KEY=/' | sed 's/region = /export AWS_DEFAULT_REGION=/'