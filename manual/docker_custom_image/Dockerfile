# This Dockerfile builds the image used for the worker containers.
FROM ubuntu:bionic

# Install required software for Terraform Enterprise.
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    sudo unzip python python-pip daemontools git-core awscli ssh wget curl psmisc iproute2 openssh-client redis-tools netcat-openbsd ca-certificates

# Include all necessary CA certificates.
ADD tfe_certificate.crt /usr/local/share/ca-certificates/


# Update the CA certificates bundle to include newly added CA certificates.
RUN update-ca-certificates
