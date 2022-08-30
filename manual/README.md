# TFE_with_custom_worker

In this repository you will use a custom worker for Terraform Enterprise to use with the azure cli installed.

This repo uses the TFE environment created by the following repo

https://github.com/munnep/TFE_aws_external

# Documentation references
HashiCorp official documentation: [See here](https://www.terraform.io/enterprise/install/interactive/installer#alternative-terraform-worker-image)  
HashiCorp Engineer Github Repo on building custom workers: [See here](https://github.com/straubt1/tfe-alternative-worker)

# Prerequisites

Have the TFE environment created by using this repo https://github.com/munnep/TFE_aws_external

# Using the repo

## build the custom docker image

- login to your TFE server in AWS
```
ssh ubuntu@patrick-tfe9.bg.hashicorp-success.com
```

- Become user root
```
sudo su -
```
- Create file `Dockerfile` with the following content
```
# This Dockerfile builds the image used for the worker containers.
FROM ubuntu:bionic

# Install required software for Terraform Enterprise.
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    sudo unzip daemontools git-core awscli ssh wget curl psmisc iproute2 openssh-client redis-tools netcat-openbsd ca-certificates

RUN apt-get update \
    && apt-get install --no-install-recommends -y ca-certificates curl apt-transport-https lsb-release gnupg \
    && curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null \
    && AZ_REPO=$(lsb_release -cs) \
    && echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | tee /etc/apt/sources.list.d/azure-cli.list \
    && apt-get update \
    && apt-get install -y azure-cli
```
- create the docker image
sudo docker build -t patrick .
- Login to the TFE dashboard
- change the value from default worker to custom worker and name it `patrick:latest`  
- Save the settings which will restart TFE

## test the new worker
- Create a new workspace in the TFE environment
- Go to the `terraform-example` directory
```
cd terraform example
```
- Edit the `main.tf` file for the correct workspace
- Run terraform init
```
terraform init
```
- terraform apply
```
terraform apply
```
- This should show you the output of the azure client `az login` command output
```
null_resource.test (local-exec): Python location '/opt/az/bin/python3'
null_resource.test (local-exec): Extensions directory '/root/.azure/cliextensions'

null_resource.test (local-exec): Python (Linux) 3.10.5 (main, Jul 29 2022, 03:27:29) [GCC 7.5.0]

null_resource.test (local-exec): Legal docs and information: aka.ms/AzureCliLegal


null_resource.test: Creation complete after 0s [id=4422853688424397371]
```



