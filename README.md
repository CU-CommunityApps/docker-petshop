# docker-petshop

An example application that uses standardized configuration and deployment processes from the Cornell Cloud DevOps team.

## To Do

* Docuemntation to create
  * petshop-elasticbeanstalk-ec2-role
* Improve the way the KMS key id is stored. It is in multiple places in the puppet-petshop repo.

## AWS Resources and Configuration

- A custom instance role is used for EC2 instances hosting the container running the application. This instance role grants the IAM privileges required by the application to run successfully.
  - instance role name: petshop-elasticbeanstalk-ec2-role
  - policies attached:
    - DockerCFGReadOnly
      - This is a custom role we use account-wide that provides access to Docker credentials for dtr.cucloud.net. This gives the Elastic Beanstalk framework running on an EC2 instance access to an S3 bucket that contains a Docker credential file for a read-only dtr.cucloud.net user. Access to the dtr.cucloud.net is required to pull docker images stored there.
    - AWS-managed policies that allow and EC2 instance to function in the Elastic Beanstalk framework:
      - AWSElasticBeanstalkWebTier
      - AWSElasticBeanstalkWorkerTier
      - AWSElasticBeanstalkMulticontainerDocker

## Puppet Configuration management

This project shows how Puppet can be used to accomplish configuration management in two different contexts:

1. during the Docker build process, controlled by the [Dockerfile](Dockerfile). This configuration is stored as part of the Docker image.
1. upon first launch of a container, controlled by a launch script [container-scripts/launch.sh](container-scripts/launch.sh). This configuration should be considered transient because it is re-applied inside every container launched from the image.

## Secrets

This project uses Puppet to decrypt encrypted secrets and configure the plaintext secrets in images and/or containers. Secrets deployed by Puppet during the Docker build process are stored in plain text in the corresponding Docker image. Secrets deployed by Puppet at container launch are stored encrypted in the corresponding Docker image. Individual teams will have different comfort levels with each of the approaches.

Regardless of when secrets are deployed by Puppet, the same two technical mechanisms can be used. In both cases [AWS Key Management Service](https://aws.amazon.com/documentation/kms/) is used for encryption and decryption. These two mechanisms are:

**Puppet and hiera-eyaml:** The [hiera-eyaml](https://github.com/TomPoulton/hiera-eyaml) and [hiera-eyaml-kms](https://github.com/adenot/hiera-eyaml-kms) gems are used to extend Puppet functionality to manage secrets directly in Puppet attribute (yaml) files which contain individually encrypted attributes. With proper configuration, Puppet attribute data are transparently decrypted for deployment by Puppet.

**Puppet and custom KMS scripting:** The approach uses whole file encryption. Puppet is used to deploy files to an image or container and then decrypt them using custom scripts.

### Secrets using KMS

Both approaches to secrets management uses AWS Key Management Service (KMS), specifically a single application-specific KMS key. See [cloud-formation/kms-key.json](cloud-formation/kms-key.json) for a CloudFormation template to create a KMS specifically for this application to manage secrets using KMS. This template creates a single KMS key with the following characteristics:
  - key name (alias): user-defined at CloudFormation stack launch
  - key administrators:
    - `shib-admin` role
      - This is the Cornell-standard master administrative role for AWS accounts.
  - key users:
    - `petshop-elasticbeanstalk-ec2-role` role
      - This is a custom instance role defined for this project.
    - `pea1` IAM user
      - This gives an IAM user permission to encrypt/decrypt via KMS CLI on a local workstation properly configured with AWS API credentials. Developers need permission to encrypt and decrypt from their local workstation as they work on the configuraiton of the project.
    - `jenkins` role
      - This role is associated with the instance profile used by the Jenkins instance building the container.

Before using the `kms-key.json` file to create a new stack, you would want to change it to reference the appropriate ARNs for similar roles and users in your AWS account. See elsewhere in this documentation for more information about the `petshop-elasticbeanstalk-ec2-role` role.

### Puppet and custom KMS scripting

With this approach, entire small files (up to 4KB) are treated as secrets and placed in the docker image in encrypted form. At Docker build time or at container launch time, Puppet uses custom scripting to decrypt those files. The 4KB limit comes from the capabilities of KMS. For larger files, you would have to use KMS data keys and key wrapping to encrypt your secrets. See [AWS Key Management Service Concepts](http://docs.aws.amazon.com/kms/latest/developerguide/concepts.html#data-keys).

Puppet resources (in the `puppet-petshop` project) required for this approach:

- `puppet-petshop/files/kms-secrets`
  - This directory contains example service configuration files and custom scripts.
  - The `kms-decrypt-files.sh` script makes KMS CLI calls to decrypt the list of files passed to it as parameters.
  - The `kms-encrypt-files.sh` script makes KMS CLI calls to encrypt the list of files passed to it as parameters. It contains a reference to the specific KMS key used by this application.
  - Files with name format like `service.{environment}.conf`. These are example  environment-specific service configuration files that would contain plain text secrets. **In a real project, these files would NOT be stored in the repo. They would be transient on a developer's workstation.**
  - Files with name format like `service.{environment}.conf.encrypted`. These are encrypted versions of the `service.{environment}.conf` files. Normally, these would be the only versions of the service configuration files to be stored in a git repo.

#### How secrets are deployed in this scenario

1. Encrypted files are stored in `puppet-petshop` git repo at `/files/kms-secrets`. E.g., `service.dev.conf.encrypted`.

1. A Docker build process is initiated by a user on a local workstation or from a Jenkins job. If secrets are to be stored in plain text in Docker images, the Puppet manifest would perform decryption at that time. If secrets are to be configured in the Docker image only in encrypted form, then decryption would be delayed until Puppet runs again at container launch time.

1. Puppet is run during the Docker build and processes the Docker build Puppet manifest.

  1. This Puppet manifest specifies that the environment-specific encrypted files be copied to the Docker image, to `/tmp/secrets/manual-kms` in this example.

  1. This Puppet manifest also specifies that the decryption script `kms-decrypt-files.sh` be copied to the Docker image, to `/tmp/secrets/manual-kms` in this example.

  1. If secrets are to be decrypted at this time (i.e. during the Docker build), the  `kms-decrypt-files.sh` is `exec`d against the encrypted files, storing the decrypted version of the file in the Docker image.

1. During the Docker build, a launch script [launch.sh](container-scripts/launch.sh) is copied to the Docker image and that script is defined as the `CMD` to be run when the container launches. This is specified in the [Dockerfile](Dockerfile). When run at container launch, the `launch.sh` script will execute Puppet against a second, launch manifest.

1. (Optional) After the Docker build process successfully completes, the resulting Docker image is tagged and stored in `dtr.cucloud.net`. Any secrets already decrypted and deployed to the image are obviously stored as well as part of the image layers.

1. When a Docker container based on the image is launched,  [launch.sh](container-scripts/launch.sh) will run. This script runs the launch Puppet manifest. If the delayed decryption approach is used, then that second Puppet manifest would specify that `kms-decrypt-files.sh` will be `exec`d to decrypt the already deployed encrypted files. After Puppet is run for the second time, the script then launches the desired primary process for the container.

See elsewhere in this document for information about passing AWS credentials to the Docker build process and to a running container. This happens in different ways, depending on the execution context.

#### Creating secrets in the custom KMS scripting scenario

Secrets will normally be configured by a developer/sysadmin working with the puppet-petshop git repo on their local workstation. The workflow would be something like the following:

1. Ensure that AWS credentials are properly configured for the current user, so that she can run AWS CLI commands on her local workstation. See [AWS CLI documentation](http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html).

1. Ensure that the AWS IAM user being used at the command line has permission to use the KMS key. This is configured in IAM in the KMS key properties.

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
  $ diff --report-identical-files service.dev.conf service.dev.conf.plaintext
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

1. Add a Puppet `exec` resource to the manifest corresponding to when context when you want decryption to happen: `puppet-petshop/manifests/app.pp` for Docker build timing, and `puppet-petshop/manifests/launch.pp` for the container launch context. In either case you would likely want a corresponding `file` Puppet resource to define the owner, group, and permissions of the decrypted file.

1. If you want Puppet to perform decryption at container launch, setup a launch script (e.g., [launch.sh](container-scripts/launch.sh)) that will run Puppet a second time with the launch manifest (e.g., `puppet-petshop/manifests/launch.pp`) to decrypt the file and set owner, group, and permissions.

#### Example AWS CLI commands to Decrypt and Encrypt files with KMS

```
aws kms encrypt --key-id 4c044060-5160-4738-9c7b-009e7fc2c104 --plaintext fileb://service.dev.conf --output text --query CiphertextBlob | base64 --decode > service.dev.conf.encrypted

aws kms decrypt --ciphertext-blob fileb://service.dev.conf.encrypted --output text --query Plaintext | base64 --decode > service.dev.conf.plaintext
```

#### Potential Improvements

- We could use different KMS keys for each environment (dev, test, prod, etc.). To accomplish this, we would have set the KMS key id as a property in puppet-petshop/hiera-data/[dev|local|prod|test].eyaml and use the Puppet templating capability to set the id of the KMS key in a template of a bash script.

### Puppet and hiera-eyaml-kms encryption

Puppet resources required for this approach:

- `puppet-petshop/files/kms-secrets`
  - This directory contains example service configuration files and custom scripts.
  - The `kms-decrypt-files.sh` script makes KMS CLI calls to decrypt the list of files passed to it as parameters.
  - The `kms-encrypt-files.sh` script makes KMS CLI calls to encrypt the list of files passed to it as parameters. It contains a reference to the specific KMS key used by this application.
  - Files with name format like `service.{environment}.conf`. These are example  environment-specific service configuration files that would contain plain text secrets. **In a real project, these files would NOT be stored in the repo. They would be transient on a developer's workstation.**
  - Files with name format like `service.{environment}.conf.encrypted`. These are encrypted versions of the `service.{environment}.conf` files. Normally, these would be the only versions of the service configuration files to be stored in a git repo.


#### Creating secrets in the hiera-eyaml-kms scenario

See `puppet-petshop/README.md` for detais on how to setup install and use hiera-eyaml-kms to encrypt and decrypt secrets using `eyaml` on a local developerw orkstation.

#### How secrets are deployed in the hiera-eyaml-kms scenario

In this approach, decryption occurs automatically (by Puppet via hiera-eyaml and hiera-eyaml-kms), when attribute values from the common.eyaml or environment-specific (e.g., dev.eyaml) properties files in `puppet-petshop/hiera-data` are used. Thus you don't need Puppet `exec` resources to manually call decryption methods. You will usually be using Puppet `file` resources with templating or other approaches to attribute value substitution.

Key configuration for this to work are:
- hiera-eyaml, hiera-eyaml-kms, and aws-sdk gems installed in container. See puppet-petshop/README.md.
- hiera-eyaml configuration in puppet-petshop/hiera.yaml
- Application-specific KMS key provisioned and configured. See [cloud-formation/kms-key.json](cloud-formation/kms-key.json) and information elsewhere in this document.

1. Encrypted secrets are stored as individual attribute values in yaml properties files in the puppet-petshop git repo at `files/hiera-data`. Attributes with values common across environments are specified in `hiera-data/common.eyaml`. Attributes with environment-specificvals are stored in files that correspond to the environment name: `dev.eyaml`. `prod.eyaml`, `local.eyaml`, `test.eyaml`.

1. A Docker build process is initiated by a user on a local workstation or from a Jenkins job.

1. For secrets that are to be stored in plain text in Docker image, the Puppet manifest would deploy/configure relevant resources in `puppet-petshop/manifests/app.pp`. Puppet is run during the Docker build by specifying the `class { 'petshop::app': }` as the Puppet manifest, which refers to `puppet-petshop/manifest/app.pp`. In the present configuration of this example, this Puppet run is used to set the stage for deploying secrets at container launch. E.g., `/tmp/secrets/hiera-eyaml-kms` directory is created and is the target for a plain text `service.conf` file at container launch.

1. During the Docker build, a launch script [launch.sh](container-scripts/launch.sh) is copied to the Docker image and that script is defined as the `CMD` to be run when the container launches. This is all specified in the [Dockerfile](Dockerfile). When run at container launch, this script will execute Puppet against a second, launch manifest `puppet-petshop/manifests/launch.pp`.

1. (Optional) After the Docker build process successfully completes, the resulting Docker image is tagged and stored in `dtr.cucloud.net`. Any secrets already decrypted and deployed to the image are obviously stored as well.

1. When a Docker container based on the image is launched,  [launch.sh](container-scripts/launch.sh) will run. This script runs the launch Puppet manifest. That manifest containers, e.g., a `file` resource that specifies that the file content should be populated from the value of the `service_conf` attribute, which will be pulled from the appropriate environment-specific eyaml file (e.g., `dev.eyaml`)

#### Building the container

If the Docker build Puppet manifest references attributes that are encrypted, we need to be sure to provide to the Docker build process AWS credentials with privileges to use the KMS key.

* If building the container on a local workstation, the following approach is suggested:

  ```
  # Setup env variables in current shell for this and later builds.
  $ export AWS_ACCESS_KEY_ID=<your_IAM_user_credentials_access_key>
  $ export AWS_SECRET_ACCESS_KEY=<your_IAM_user_credentials_secret_key>
  # Pass those values into the build
  $ docker build --build-arg DOCKER_ENV=local --build-arg AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID --build-arg AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY -t petshop .
  ```

* If building the container in Jenkins, use the [docker-build.sh](build-scripts/docker-build.sh) script. The role that Jenkins is assigned in EC2 must have permissions to use the KMS key.

* You can also use the [docker-build.sh](build-scripts/docker-build.sh) script on a local workstartion to build the image. Be aware that it expects AWS CLI credentials to be set as  environment variables (as shown above) in the shell used to launch the build script. Note that beyond building the image, the script also tags it and stores it in dtr.cucloud.net.

#### Running the container

If the container is being launched in EC2, then the EC2 instance would need to need be assigned the `petshop-elasticbeanstalk-ec2-role` instance role, which is configured to be allowed to use the application-specific KMS key. This instance role is set in Elastic Beanstalk environment configuration and described elsewhere in this documentation.

If the container is being launched on a local workstation, you will need to ensure that the container has access to AWS API credentials for calls to KMS to work. An easy way to accomplish that is to map your own AWS credentials file to the where those credentials should be reside in the container. When AWS API calls are made inside the container by the root user, the AWS API/SDK expect to find credentials in the container at `/root/.aws`. Therefore, launch the container locally with the following docker run volume mapping:

  ```
  docker run --rm -p 8080:8080 -v ~/.aws:/root/.aws --name petshop petshop
  ```


## Misc notes when running the container locally

* Clean up your local docker image storage:

  ```
  docker rm $(docker ps -a -q)
  ```
* Connect to the running container, and run a bash shell:

  ```
  docker exec -it petshop bash
  ```
