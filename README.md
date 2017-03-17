# docker-petshop

This is a trivial example application that uses standardized (but complex) configuration and deployment processes from the Cornell Cloud DevOps team. This repo has a sister repo [puppet-petshop](https://github.com/CU-CommunityApps/puppet-petshop) that contains Puppet configuration required for the project.

## Features

- Application runs in a Docker container
- Containers are deployed using Elastic Beanstalk
- Puppet is used for configuration management during Docker build and, optionally, during container launch
- Secrets are managed by Puppet and encrypted using AWS Key Management Service

## To Do

* Improve the way the KMS key id is stored. It is in multiple places in the puppet-petshop repo, specificall in `puppet-petshop/hiera.eyaml` and `puppet-petshop/files/kms-secrets/kms-encrypt-files.sh`.
* Finish instructions.

# Instructions

For instructions on using this example, see [Step-by-step Instructions](INSTRUCTIONS.md).

## Static AWS Resources and Configuration

- *S3 Bucket* A bucket is used to store the Docker credentials file that Elastic Beanstalk requires to authenticate to `dtr.cucloud.net` as a read-only user. See [Docker Credentials Management](https://confluence.cornell.edu/x/oQRfF) for information about that type of credentials file. This bucket should be configured as a private bucket with no bucket policies. The IAM instance profile below, gives access to the bucket for AWS processes that need it.
- *IAM Role/Instance Profile* A custom instance profile is used for EC2 instances hosting the container running the application. This instance role grants the IAM privileges required by the application to run successfully.
  - instance role name: petshop-elasticbeanstalk-ec2-role
  - policies attached:
    - DockerCFGReadOnly
      - This is a custom policy that provides access to Docker credentials file for dtr.cucloud.net which is stored in a private bucket. The IAM policy is defined as follows:
      ```json
      {
        "Version": "2012-10-17",
        "Statement": [
        {
            "Sid": "Stmt1466096728000",
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket"
            ],
            "Resource": [ "arn:aws:s3:::BUCKET_NAME" ]
        }, {
            "Sid": "Stmt1466096728001",
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:HeadObject",
                "s3:ListBucket"
            ],
            "Resource": [ "arn:aws:s3:::BUCKET_NAME/.dockercfg" ]
          }
        ]
      }
      ```
    - AWS-managed policies that allow and EC2 instance to function in the Elastic Beanstalk framework:
      - AWSElasticBeanstalkWebTier
      - AWSElasticBeanstalkWorkerTier
      - AWSElasticBeanstalkMulticontainerDocker
  - An AWS Key Management Service encryption key. This custom key is used to encrypt/decrypt  secrets for the project. A CloudFormation template for that resides in [cloud-formation/kms-key.json](cloud-formation/kms-key.json).

## Puppet Configuration management

This project shows how Puppet can be used to accomplish configuration management in two different contexts:

1. during the Docker build process, controlled by the [Dockerfile](Dockerfile). This configuration is stored as part of the Docker image.
1. upon first launch of a container, controlled by a launch script [container-scripts/launch.sh](container-scripts/launch.sh). This configuration should be considered transient because it is re-applied inside every container launched from the image.

## Secrets

See[Secrets with Puppet](PUPPET_SECRETS.md).

### Puppet and custom KMS scripting

See [Puppet and custom KMS scripting](PUPPET_KMS_SCRIPT.md).

### Puppet and hiera-eyaml-kms encryption

See [Puppet and hiera-eyaml-kms encryption](PUPPET_EYAML.md).

## Building Docker Images and Running Containers

See [# Building Images and Running Containers](DOCKER_BUILD_RUN.md).
