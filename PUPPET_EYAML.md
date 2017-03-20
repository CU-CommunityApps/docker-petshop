# Secret management in Puppet using hiera-eyaml-kms

This approach uses encryption/decryption integrated into Puppet by the [hiera-eyaml-kms plugin](https://github.com/adenot/hiera-eyaml-kms) for the the [hiera-eyaml tool](https://github.com/voxpupuli/hiera-eyaml).

Puppet resources required for this approach:

- `puppet-petshop/hiera-data/[dev|local|prod|test].eyaml`
  - These `yaml` properties files contain environment-specific values that will be used by Puppet and injected into templates or used in other ways in Puppet manifests. Some individual properties are encrypted.
- `puppet-petshop/templates/service.conf.erb`
  - This is a sample service configuration template file that contains references to variables derived from the properties files `hiera-data`.
- `puppet-petsgop/hiera.yaml`
  - This file contains configuration for the hiera-eyaml tool itself. Most importantly the `:kms_key_id` key references the ID of the KMS to use for encryption/decryption. You will need set that value to match the ID for the key you create in your AWS account.

## Getting hiera-eyaml-kms setup on a local workstation

1. Create a KMS key for hiera-eyaml-kms to use.

    See [Secrets Using KMS](PUPPET_SECRETS.md#secrets-using-kms) in this repo.

1. Install hiera-eyaml and supporting gems on the local workstation:
    ```
    $ gem install hiera-eyaml
    $ gem install aws-sdk
    $ gem install hiera-eyaml-kms
    ```

1. Setup an the eyaml config file for your workstation user. Copy and paste the lines below into  `~/.eyaml/config.yaml` for your local workstation user. Replace the KMS key id with the one you created above.
    ```
    encrypt_method: 'KMS'
    kms_key_id: '4c044060-5160-4738-9c7b-009e7fc2c104'
    kms_aws_region: 'us-east-1'
    ```

    If you wish, you can skip setup of the `~/.eyaml/config.yaml` file and use these eyaml arguments each time you execute it:

    ```
    --kms-key-id=<your_KMS_key_id> --kms-aws-region=<your_AWS_region> --encrypt-method=KMS
    ```

1. Confirm that hiera-eyaml works and knows about the KMS plugin.
    ```
    $ eyaml version
    [hiera-eyaml-core] Loaded config from /Users/pea1/.eyaml/config.yaml
    [hiera-eyaml-core] hiera-eyaml (core): 2.1.0
    [hiera-eyaml-core] hiera-eyaml-kms (gem): 0.1
    ```

1. Test string encryption.
    ```
    $ eyaml encrypt -s "Hello world"
    [hiera-eyaml-core] Loaded config from /Users/pea1/.eyaml/config.yaml
    string: ENC[KMS,AQECAHhpScaf3XF9NVK+U6wXpeDoju8w8Ccbz3O4+LbMCXi+UQAAAGkwZwYJKoZIhvcNAQcGoFowWAIBADBTBgkqhkiG9w0BBwEwHgYJYIZIAWUDBAEuMBEEDLz6zMdtnIsNxNzw9gIBEIAmhv1St9i1uybeGDyq6bWgQvt8C3uDK5W8bYdwrBdPDgYjJvKIrPs=]

    OR

    block: >
        ENC[KMS,AQECAHhpScaf3XF9NVK+U6wXpeDoju8w8Ccbz3O4+LbMCXi+UQAAAGkwZwYJ
        KoZIhvcNAQcGoFowWAIBADBTBgkqhkiG9w0BBwEwHgYJYIZIAWUDBAEuMBEE
        DLz6zMdtnIsNxNzw9gIBEIAmhv1St9i1uybeGDyq6bWgQvt8C3uDK5W8bYdw
        rBdPDgYjJvKIrPs=]
    ```

1. Test string decryption using the encrypted data from above:
    ```
    $ eyaml decrypt -s ENC[KMS,AQECAHhpScaf3XF9NVK+U6wXpeDoju8w8Ccbz3O4+LbMCXi+UQAAAGkwZwYJKoZIhvcNAQcGoFowWAIBADBTBgkqhkiG9w0BBwEwHgYJYIZIAWUDBAEuMBEEDLz6zMdtnIsNxNzw9gIBEIAmhv1St9i1uybeGDyq6bWgQvt8C3uDK5W8bYdwrBdPDgYjJvKIrPs=]
    [hiera-eyaml-core] Loaded config from /Users/pea1/.eyaml/config.yaml
    Hello world
  ```

1. Troubleshooting. Use the `--trace` option with eyaml to get more details about what it's doing.
    ```
    $ eyaml encrypt --trace -s "Hello world"
    [hiera-eyaml-core] Loaded config from /Users/pea1/.eyaml/config.yaml
    [hiera-eyaml-core] Dump of eyaml tool options dict:
    [hiera-eyaml-core] --------------------------------
    [hiera-eyaml-core]           (Symbol) encrypt_method     =           (String) KMS               
    [hiera-eyaml-core]           (Symbol) version            =       (FalseClass) false             
    [hiera-eyaml-core]           (Symbol) verbose            =       (FalseClass) false             
    [hiera-eyaml-core]           (Symbol) trace              =        (TrueClass) true              
    [hiera-eyaml-core]           (Symbol) quiet              =       (FalseClass) false             
    [hiera-eyaml-core]           (Symbol) help               =       (FalseClass) false             
    [hiera-eyaml-core]           (Symbol) password           =       (FalseClass) false             
    [hiera-eyaml-core]           (Symbol) string             =           (String) Hello world       
    [hiera-eyaml-core]           (Symbol) file               =         (NilClass)                   
    [hiera-eyaml-core]           (Symbol) stdin              =       (FalseClass) false             
    [hiera-eyaml-core]           (Symbol) eyaml              =         (NilClass)                   
    [hiera-eyaml-core]           (Symbol) output             =           (String) examples          
    [hiera-eyaml-core]           (Symbol) label              =         (NilClass)                   
    [hiera-eyaml-core]           (Symbol) pkcs7_private_key  =           (String) ./keys/private_key.pkcs7.pem
    [hiera-eyaml-core]           (Symbol) pkcs7_public_key   =           (String) ./keys/public_key.pkcs7.pem
    [hiera-eyaml-core]           (Symbol) pkcs7_subject      =           (String) /                 
    [hiera-eyaml-core]           (Symbol) kms_key_id         =           (String) 4c044060-5160-4738-9c7b-009e7fc2c104
    [hiera-eyaml-core]           (Symbol) kms_aws_region     =           (String) us-east-1         
    [hiera-eyaml-core]           (Symbol) trace_given        =        (TrueClass) true              
    [hiera-eyaml-core]           (Symbol) string_given       =        (TrueClass) true              
    [hiera-eyaml-core]           (Symbol) executor           =            (Class) Hiera::Backend::Eyaml::Subcommands::Encrypt
    [hiera-eyaml-core]           (Symbol) source             =           (Symbol) string            
    [hiera-eyaml-core]           (Symbol) input_data         =           (String) Hello world       
    [hiera-eyaml-core] --------------------------------
    string: ENC[KMS,AQECAHhpScaf3XF9NVK+U6wXpeDoju8w8Ccbz3O4+LbMCXi+UQAAAGkwZwYJKoZIhvcNAQcGoFowWAIBADBTBgkqhkiG9w0BBwEwHgYJYIZIAWUDBAEuMBEEDGHlknGK3qO7dJcdXAIBEIAm7GxN3b8dxll4mBUMdyC6W9ln69Zp11rgs6GupHty6uB/kgKpAd0=]

    OR

    block: >
        ENC[KMS,AQECAHhpScaf3XF9NVK+U6wXpeDoju8w8Ccbz3O4+LbMCXi+UQAAAGkwZwYJ
        KoZIhvcNAQcGoFowWAIBADBTBgkqhkiG9w0BBwEwHgYJYIZIAWUDBAEuMBEE
        DGHlknGK3qO7dJcdXAIBEIAm7GxN3b8dxll4mBUMdyC6W9ln69Zp11rgs6Gu
        pHty6uB/kgKpAd0=]
    ```

## Configure hiera-eyaml-kms for Puppet

1. Edit the `puppet-petshop/hiera.yaml` file and replace the value for `:kms_key_id:` with the KMS key ID you created and tested above.

## Creating secrets in this scenario

There are variety of ways to create secrets using hiera-eyaml-kms.

* Creating secrets at the command line:

  ```
  $ eyaml encrypt -f filename            # Encrypt an entire file
  $ eyaml encrypt -s 'Hello world'       # Encrypt a string
  $ eyaml encrypt -p                     # Encrypt a password (prompt for it)
  ```

  Copy and paste the encrypted values into the properties files in `puppet-petshop/hier-eyaml`.

* Edit `.eyaml` files with the editor configured for your shell:

  ```
  $ eyaml edit hiera-data/filename.eyaml       # Edit an eyaml file in place
  ```

  See the [voxpupuli/hiera-eyaml documentation](https://github.com/voxpupuli/hiera-eyaml#editing-eyaml-files) for more details about this approach.

* Edit `.eyaml` files with the editor you usually use for source code.

  Editors like [Atom](https://atom.io/) have [plugins](https://atom.io/packages/hiera-eyaml) that support encrypting and decrypting values directly within them. You will need to make sure that the editor and/or package is configured properly to use KMS encryption and the right KMS key.

## How secrets are deployed in Docker images and containers in this scenario

In this approach, decryption occurs automatically (by Puppet via hiera-eyaml and hiera-eyaml-kms), when attribute values from the `common.eyaml` or environment-specific (e.g., `dev.eyaml`) properties files in `puppet-petshop/hiera-data` are used. Thus you don't need Puppet `exec` resources to manually call decryption methods. You will usually be using Puppet `file` resources with templating or other approaches to attribute value substitution.

Key configuration for this to work are:
- `hiera-eyaml`, `hiera-eyaml-kms`, and `aws-sdk` gems installed in the container where the application runs.
- `hiera-eyaml` configuration in `puppet-petshop/hiera.yaml`
- An application-specific KMS key is provisioned and configured. See [cloud-formation/kms-key.json](cloud-formation/kms-key.json) and information elsewhere in this document.

1. Encrypted secrets are stored as individual attribute values in `.eyaml` properties files in the `puppet-petshop` git repo at `hiera-data`. Attributes with values common across environments are specified in `hiera-data/common.eyaml`. Attributes with environment-specific values are stored in files that correspond to the environment name: e.g, `dev.eyaml`. `prod.eyaml`, `local.eyaml`, `test.eyaml`.

1. A Docker build process is initiated by a user on a local workstation or from a Jenkins job.

1. For secrets that are to be stored in plain text in the Docker image, the Puppet manifest would deploy/configure relevant resources according to `puppet-petshop/manifests/app.pp`. Puppet is run during the Docker build by specifying the `class { 'petshop::app': }` as the Puppet manifest in the [Dockerfile](Dockerfile). In the present configuration of this example:
  1. This Puppet run is used to set the stage for deploying secrets during the build and at container launch. E.g., `/tmp/secrets/hiera-eyaml-kms` directory is created.
  1. The `service.build.conf` file is created from the `service.conf.erb` template and properties referenced in it are replaced with plaintext values.

1. During the Docker build, a launch script [launch.sh](container-scripts/launch.sh) is copied to the Docker image and that script is defined as the `CMD` to be run when the container launches. This is all specified in the [Dockerfile](Dockerfile). When run at container launch, this script will execute Puppet against a second, launch manifest `puppet-petshop/manifests/launch.pp`.

1. (Optional) After the Docker build process successfully completes, the resulting Docker image is tagged and stored in `dtr.cucloud.net`. Any secrets already decrypted and deployed to the image are stored inside the image as plain text.

1. When a Docker container based on the image is launched, [launch.sh](container-scripts/launch.sh) will run. This script runs the launch Puppet manifest `puppet-petshop/manifests/launch.pp`. In this example, at launch:
  1. The plaintext configuration file `service.launch.whole-file.conf` is created, based on the encrypted content of the `service_conf` attribute, , which will be pulled from the appropriate environment-specific eyaml file (e.g., `dev.eyaml`)
  1. The `service.launch.conf` file is created from the `service.conf.erb` template and properties referenced in it are replaced with plaintext values.

## Miscellaneous notes

### Use eyaml to encrypt whole files.

```
eyaml encrypt -f service.dev.conf | grep string | cut -c 9- | tr -d '\n' > service.dev.conf.eyaml-encrypted
eyaml decrypt -f service.dev.conf.eyaml-encrypted > service.dev.conf.eyaml-decrypted
diff --report-identical-files service.dev.conf service.dev.conf.eyaml-decrypted
```

### Use hiera directly from within container

Puppet uses the `hiera` tool to lookup attribute values from `hiera-eyaml` properties files. You can also use this tool directly in a shell script in a container if the Puppet tooling is present.

```
$ hiera -c /modules/petshop/hiera.yaml petshop_password environment=local
'dummy-local-password'
$
```
