# Secrets with Puppet

This project uses Puppet to decrypt encrypted secrets and configure the plaintext secrets in images and/or containers. Secrets deployed by Puppet during the Docker build process are stored in plain text in the corresponding Docker image. Secrets deployed by Puppet at container launch are stored encrypted in the corresponding Docker image. Individual teams may have different comfort levels with each of the approaches.

Regardless of when secrets are deployed by Puppet, the same two technical mechanisms can be used. In both cases [AWS Key Management Service](https://aws.amazon.com/documentation/kms/) is used for encryption and decryption. The two mechanisms are:

**Puppet and hiera-eyaml:** The [hiera-eyaml](https://github.com/voxpupuli/hiera-eyaml) and [hiera-eyaml-kms](https://github.com/adenot/hiera-eyaml-kms) gems are used to extend Puppet functionality to manage secrets directly in Puppet attribute (yaml) files which contain individually encrypted attributes. With proper configuration, Puppet attribute data are transparently decrypted for deployment by Puppet.

**Puppet and custom KMS scripting:** The approach uses whole file encryption. Puppet is used to deploy files to an image or container and then decrypt them using custom scripts.

## Secrets using KMS

Both approaches to secrets management uses AWS Key Management Service (KMS), specifically a single application-specific KMS key. See [cloud-formation/kms-key.json](cloud-formation/kms-key.json) for a CloudFormation template to create a KMS specifically for this application to manage secrets using KMS. This template creates a single KMS key with the following characteristics:
  - key name (alias): user-defined at CloudFormation stack launch
  - key administrators:
    - `shib-admin` role
      - This is the Cornell-standard master administrative role for AWS accounts.
  - key users:
    - An IAM role, default: `petshop-elasticbeanstalk-ec2-role`
      - Use this parameter to specify the instance profile defined for this project.
    - An IAM role for Jenkins, default `Jenkins`
      - This role is associated with the instance profile used by the EC2 instance running Jenkins and building the container for the project.
    - An IAM user, default: `pea1`
      - Use this parameter to give the spEcified IAM user permission to encrypt/decrypt via KMS CLI on a local workstation properly configured with AWS API credentials. Developers need permission to encrypt and decrypt from their local workstation as they work on the configuration of the project.

Before using the `kms-key.json` file to create the KMS key using CloudFormation, you may want to change it to reference other releveant ARNs for similar roles and users in your AWS account.

## Secret management in Puppet using custom KMS scripting

See [Secret management in Puppet using custom KMS scripting](PUPPET_KMS_SCRIPT.md).

## Secret management in Puppet using hiera-eyaml-kms

See [Secret management in Puppet using hiera-eyaml-kms](PUPPET_EYAML.md).