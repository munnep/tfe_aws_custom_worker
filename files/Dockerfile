# This Dockerfile builds the image used for the worker containers.
FROM ubuntu:bionic

# Install required software for Terraform Enterprise.
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    sudo unzip daemontools git-core awscli ssh wget curl psmisc iproute2 openssh-client redis-tools netcat-openbsd ca-certificates

# # Include all necessary CA certificates.
ADD tfe_certificate.crt /usr/local/share/ca-certificates/

# # Update the CA certificates bundle to include newly added CA certificates.
RUN update-ca-certificates


# install the Azure cli tool
RUN apt-get update \
    && apt-get install --no-install-recommends -y ca-certificates curl apt-transport-https lsb-release gnupg \
    && curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null \
    && AZ_REPO=$(lsb_release -cs) \
    && echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | tee /etc/apt/sources.list.d/azure-cli.list \
    && apt-get update \
    && apt-get install -y azure-cli