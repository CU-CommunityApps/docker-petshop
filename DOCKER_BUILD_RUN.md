# Building Images and Running Containers

## Building the Image

If the Docker build Puppet manifest references attributes that are encrypted or uses KMS in any other way, we need to be sure to provide to the Docker build process with AWS credentials that have privileges to use the KMS key.

### Building the container on a local workstation

**WARNING!!!** *In order to be safe, you must use temporary AWS credentials retrieved by using dtr.cucloud.net/cs/samlapi as below or some other means. The build steps outlined below (or by using [build-scripts/docker-build.sh](build-scripts/docker-build.sh)) result in a Docker image with AWS credentials embedded in metadata. Use only temporary AWS credentials for this process.*

1. Ensure working directory for your shell is `docker-petshop`.

1. Obtain temporary AWS credentials using the process described in [Using Shibboleth for AWS API and CLI access](https://blogs.cornell.edu/cloudification/2016/07/05/using-shibboleth-for-aws-api-and-cli-access/).

  ```
  $ docker run -it --rm -v ~/.aws:/root/.aws dtr.cucloud.net/cs/samlapi
  ```

1. Export the temporary AWS credentials into the current shell.

  ```
  $ eval $(build-scripts/export-saml-creds.sh)
  ```

1. Do the Docker build:

  ```
  # invalidate Docker caching
  $ date > version

  # build the image
  $ docker build --build-arg DOCKER_ENV=local --build-arg AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID --build-arg AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY --build-arg AWS_SESSION_TOKEN=$AWS_SESSION_TOKEN -t petshop .
  ```

### Building the container in Jenkins

If building the container in Jenkins, use the [docker-build.sh](build-scripts/docker-build.sh) script. The IAM instance profile that Jenkins is assigned in EC2 must have permissions to use the KMS key.  Note that beyond building the image, the script also tags it and stores it in dtr.cucloud.net.

You can also use the [docker-build.sh](build-scripts/docker-build.sh) script on a local workstation to build the image.

## Running the container

### Running the container in AWS

If the container is being launched in EC2, then the EC2 instance would need to need be assigned the `petshop-elasticbeanstalk-ec2-role` instance role, which is configured with privileges to use the application-specific KMS key. This instance role is set in Elastic Beanstalk environment configuration and described elsewhere in this documentation.

### Running the container on a local workstation

If the container is being launched on a local workstation, you will need to ensure that the container has access to AWS API credentials for calls to KMS to work. An easy way to accomplish that is to map your own AWS credentials file to the where those credentials should be reside in the container. When AWS API calls are made inside the container by the root user, the AWS API/SDK expect to find credentials in the container at `/root/.aws`. Therefore, launch the container locally with the following docker run volume mapping:

```
docker run --rm -p 8080:8080 -v ~/.aws:/root/.aws --name petshop petshop
```