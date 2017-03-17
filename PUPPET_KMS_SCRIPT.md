# Secret management in Puppet using custom KMS scripting

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

1. (Optional) After the Docker build process successfully completes, the resulting Docker image is tagged and stored in `dtr.cucloud.net`. **Any secrets already decrypted and deployed to the image are stored as part of the image layers.**

1. When a Docker container based on the image is launched,  [launch.sh](container-scripts/launch.sh) will run. This script runs the launch Puppet manifest. If the delayed decryption approach is used, then that second Puppet manifest would specify that `kms-decrypt-files.sh` will be `exec`d to decrypt the already deployed encrypted files. After Puppet is run for the second time, the script then launches the desired primary process for the container.

See elsewhere in this document for information about passing AWS credentials to the Docker build process and to a running container. This happens in different ways, depending on the execution context.

#### Creating secrets in the custom KMS scripting scenario

Secrets will normally be configured by a developer/sysadmin working with the `puppet-petshop` git repo on their local workstation. The workflow would be something like the following:

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
  $ git commit -m "add encrypted configuration file for service.conf in dev environment"
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

