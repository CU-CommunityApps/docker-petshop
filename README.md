# docker-petshop

An example application that uses standardized configuration and deployment processes from the Cornell Cloudification team.

## AWS Resources and Configuration

- A custom instance role is used for EC2 instances. This instance role grants the IAM privileges required by the application to run successfully.
  - instance role name: petshop-elasticbeanstalk-ec2-role
  - policies attached:
    - DockerCFGReadOnly
      - This is a custom role we use account-wide that provides access to Docker credentials for dtr.cucloud.net. This gives the Elastic Beanstalk framework running on an EC2 instance access to an S3 bucket that contains a Docker credential file for a read-only dtr.cucloud.net user. Access to the dtr.cucloud.net is required to pull docker images stored there.
    - AWS-managed policies that allow and EC2 instance to function in the Elastic Beanstalk framework:
      - AWSElasticBeanstalkWebTier
      - AWSElasticBeanstalkWorkerTier
      - AWSElasticBeanstalkMulticontainerDocker

## Secrets

This example shows two different methods for managing secrets:

**Puppet/eyaml:** Using eyaml and Puppet to decrypt secrets during the docker build process. Encrypted secrets are stored in the puppet-petshop repo. The plaintext of secrets are embedded in Docker images, which are typically stored in dtr.cucloud.net. This method focuses on using treating individual atttributes/properties in yaml files as secrets.

**KMS/custom:** Custom scripting that uses the AWS Key Management Service (KMS) to decrypt secrets at container launch time. This method leaves secrets encrypted in Docker images stored in dtr.cucloud.net. This method focuses on treating entire files as secret.

### Secrets using eyaml

To be documented...

### Decrypting secrets at launch

With this approach, entire small files (up to 4KB) are treated as secrets and placed in the docker image in encrypted form. At container launch time, we use custom scripting to decrypt those files. The 4KB limit comes from the capabilities of KMS. For larger files, you would have to use KMS data keys and key wrapping to encrypt your secrets. See [AWS Key Management Service Concepts](http://docs.aws.amazon.com/kms/latest/developerguide/concepts.html#data-keys).

AWS resource configuration required for this approach:

- An application-specific KMS encryption key is created and used for encryption and decryption.
  - key name: petshop-demo-key
  - key administrators:
    - shib-admin role
    - pea1 IAM user
  - key users:
    - shib-admin role
    - petshop-elasticbeanstalk-ec2-role role
    - pea1 IAM user
      - this gives permission to encrypt/decrypt via KMS CLI on a local workstation

Puppet resources required for this approach:

- `puppet-petshop/files/kms-secrets`
  - This directory contains example service configuration files and custom scripts.
  - The `kms-decrypt-files.sh` script makes KMS CLI calls to decrypt the list of files passed to it as parameters.
  - The `kms-encrypt-files.sh` script makes KMS CLI calls to encrypt the list of files passed to it as parameters. It contains a reference to the specific KMS key used by this application.
  - Files with name format like `service.{environment}.conf`. These are example  environment-specific service configuration files that would contain plain text secrets. **In a real project, these files would NOT be stored in the repo. They would be transient on a developer's workstation.**
  - Files with name format like `service.{environment}.conf.encrypted`. These are encrypted versions of the `service.{environment}.conf` files. Normally, these would be the only versions of the service configuration files to be stored in a git repo.

#### How secrets are deployed in this scenario:

1. Encrypted files are stored in puppet-petshop git repo at `/files/kms-secrets`. E.g., `service.{environment}.conf.encrypted`.

1. A Docker build process is initiated by a user on a local workstation or from a Jenkins job.

1. Puppet is run during the Docker build and processes the Puppet manifest.

  a. The Puppet manifest specifies that the environment-specific encrypted files be copied to the Docker image, to `/tmp/secrets` this example.

  b. The Puppet manifest specifies that the decryption script `kms-descrypt-files.sh` be copied to the Docker image, to `/tmp/secrets` in this example.

1. During the Docker build, a launch script [launch.sh](container-scripts/launch.sh) is copied to the Docker image and that script is defined as the `CMD` to be run when the container launches. This is all specified in the [Dockerfile](Dockerfile).

1. (Optional) After the Docker build process successfully completes, the resulting Docker image is tagged and stored in `dtr.cucloud.net`.

1. When a Docker container based on the image is launched,  [launch.sh](container-scripts/launch.sh) will run. This script uses  `kms-decrypt-files.sh` to decrypt the encrypted files, then it launches the desired primary process for the container. There are two ways to give the container the privileges to use the KMS CLI and the application-specific KMS key:

  a. If being launched on a local workstation, a developer would provide her AWS credentials to the container by using Docker volume mapping. Specifically, we map the current user's ~/.aws directory to the container user (root) that will be executing AWS CLI commands. The Docker build and run sequence would look something like:

    ```
    $ docker build --build-arg DOCKER_ENV=test -t petshop .

    $ docker run --rm -p 8080:8080 -v ~/.aws:/root/.aws petshop
    ```

  b. If the container is being launched in EC2, then the EC2 instance would need to need be assigned the `petshop-elasticbeanstalk-ec2-role` instance role, which is configured to be a user of the application-specific KMS key. This instance role is set in Elastic Beanstalk environment configuration.

### Creating secrets in this scenario

Secrets will normally be configured by a developer/sysadmin working with the puppet-petshop git repo on their local workstation. The workflow would be something like the following:

1. Ensure that AWS credentials are properly configured for the current user, so that she can run AWS CLI commands on her local workstation. See [AWS CLI documentation](http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html).

1. Ensure that the AWS IAM user being used at the command line has permission to use the KMS key. This is configured in IAM in the key properties.

1. Ensure that the proper KMS key id is referenced in the encryption script `puppet-petshop/files/kms-secrets/kms-encrypt-files.sh`

1. The user creates a file containing plaintext secrets. E.g. `puppet-petshop/files/kms-secrets/service.dev.conf`.

1. The user encrypts this file using the script `puppet-petshop/files/kms-secrets/kms-encrypt-files.sh`:

  ```
  # Current directory is puppet-petshop/files/kms-secrets
  $ ./kms-encrypt-files.sh service.dev.conf
  Processing service.dev.conf -      545 bytes. Saving to service.dev.conf.encrypted.
  ```

  This creates the file `service.dev.conf.encrypted`.

1. (Optional) Convince yourself that the file decrypts back to the original plaintext.

  ```
  # Current directory is puppet-petshop/files/kms-secrets
  $ cp service.dev.conf service.dev.conf.plaintext
  $ ./kms-decrypt-files.sh service.dev.conf.encrypted
  Processing service.dev.conf.encrypted. Decrypting to service.dev.conf.
  $ diff  --report-identical-files service.dev.conf service.dev.conf.plaintext
  Files service.dev.conf and service.dev.conf.plaintext are identical
  $ rm service.dev.conf.plaintext
  ```

1. Delete the original plaintext secrets file. Or, at least ensure that you don't add it to your git repo. You might want to utilize your `.gitignore` file to explicitly exclude plaintext secrets files from git.

1. Add the encrypted file to your git branch and commit it.

  ```
  # Current directory is puppet-petshop
  $ git add files/kms-secrets/service.dev.conf.encrypted
  $ git commit -m "add encrypted configured file for service.conf in dev environment"
  $ git push
  ```

1. Configure your Puppet manifest to deploy your encrypted file and the decryption script, contents as is, to the Docker image. Do that in `puppet-petshop/manifests/app.pp`.

1. Setup a launch script (e.g., [launch.sh](container-scripts/launch.sh)) to decrypt the file and ensure it has the right linux group ownership and permissions in the container.

1. Ensure that your [Dockerfile](Dockerfile) is configured to call your decryption script at container launch (instead of at Docker build time).

#### Potential Improvements

- We could use different KMS keys for each environment (dev, test, prod, etc.). To accomplish this, we would have set the KMS key id as a property in puppet-petshop/hiera-data/[dev|local|prod|test].eyaml and use the Puppet templating capability to set the id of the KMS key in a template of a bash script.


### AWS CLI commands to Decrypt and Encrypt files with KMS

```
aws kms encrypt --key-id 4c044060-5160-4738-9c7b-009e7fc2c104 --plaintext fileb://service.dev.conf --output text --query CiphertextBlob | base64 --decode > service.dev.conf.encrypted

aws kms decrypt --ciphertext-blob fileb://service.dev.conf.encrypted --output text --query Plaintext | base64 --decode > service.dev.conf.plaintext
```

## Build/Run container locally

```
docker rm $(docker ps -a -q)

docker build --build-arg DOCKER_ENV=test -t petshop .

# provide awscli credentials
docker run --rm -p 8080:8080 -v ~/.aws:/root/.aws --name petshop petshop

docker exec -it petshop bash
```

## hiera-eyaml

- https://github.com/TomPoulton/hiera-eyaml

```
$ gem install hiera-eyaml
$ eyaml createkeys
```