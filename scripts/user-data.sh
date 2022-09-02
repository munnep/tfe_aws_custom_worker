#!/bin/bash

# first is Alvaro
cat >> /home/ubuntu/.ssh/authorized_keys <<EOF
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDBzMaSE9ORQsJoIi+UrMQ+U8WFSpiYFXIKSvqFWbqyhpEM6MSoidX09CuvYIVPMtTeZZj/ZO+o+nL0TffIDNzkGgalhdlw5RL9OgJXgmUNWjW4VwIoR96D7TcP6EUyXkD0wxSgjryJSn4aONR3tIIYvHdM9YjRrivLlS/N7WzIRM6xvWJ8UK7fVYdD3V6FMp4+a33Uc+Ezk8XPWCvDt5vXluFPiKa8RlU7XXqPqI2bR89VJ5cpCnZorVtjVVlvgtOFdY/5hT7qqX1hxQyARkSLcnJiVylL3H3arDlnT/6nO71WY2/ZfyVUbQqcTC12UpFSJRH7JRCgf0stTdfzugCsq61XCMkZBfZ2OTBWeO8Qm2yDW7d4NwzKj31xKqDxT3sr7Gz6qiJO0XhaEjgBSAFB41hVDaNR8Fa6Ir1DObVQ+QsHOv4m2xhh8XxLaZZh30KWZNFAxVmeXoec0paDuj53UTM/ddhbKQr+8vPkbdlR4p5hxSSoVH+SBNLmGY4+K+0= kikitux@kikitux-C02ZR1GLLVDM
EOF

# wait until archive is available. Wait until there is internet before continue
until ping -c1 archive.ubuntu.com &>/dev/null; do
 echo "waiting for networking to initialise"
 sleep 3 
done 

# install monitoring tools
apt-get update
apt-get install -y ctop net-tools sysstat jq

# Set swappiness
if test -f /sys/kernel/mm/transparent_hugepage/enabled; then
  echo never > /sys/kernel/mm/transparent_hugepage/enabled
fi

if test -f /sys/kernel/mm/transparent_hugepage/defrag; then
  echo never > /sys/kernel/mm/transparent_hugepage/defrag
fi

# heavy swap vm.swappiness=80
# no swap vm.swappiness=1
sysctl vm.swappiness=1
sysctl vm.min_free_kbytes=67584
sysctl vm.drop_caches=1
# make it permanent over server reboots
echo vm.swappiness=1 >> /etc/sysctl.conf
echo vm.min_free_kbytes=67584 >> /etc/sysctl.conf


# we get a list of disk
DISKS=($(lsblk  -p -I 259 -n -o SIZE | tail +3 | tr -d 'G'))

if [ $${DISKS[1]} -gt $${DISKS[0]} ]; then
	SWAP="/dev/nvme1n1"
	DOCKER="/dev/nvme2n1"
else
	SWAP="/dev/nvme2n1"
	DOCKER="/dev/nvme1n1"
fi

# swap
# if SWAP exists
# we format if no format
if [ -b $SWAP ]; then
	blkid $SWAP
	if [ $? -ne 0 ]; then
		mkswap $SWAP
	fi
fi

# if SWAP not in fstab
# we add it
grep "$SWAP" /etc/fstab
if [ $? -ne 0 ]; then
	echo "$SWAP swap swap defaults 0 0" | tee -a /etc/fstab
	swapon -a
fi

# docker
# if DOCKER exists
# we format if no format
if [ -b $DOCKER ]; then
	blkid $DOCKER
	if [ $? -ne 0 ]; then
		mkfs.xfs $DOCKER
	fi
fi

# if DOCKER not in fstab
# we add it
grep "$DOCKER" /etc/fstab
if [ $? -ne 0 ]; then
	echo "$DOCKER /var/lib/docker xfs defaults 0 0" | tee -a /etc/fstab
	mkdir -p /var/lib/docker
	mount -a
fi

# Netdata will be listening on port 19999
curl -sL https://raw.githubusercontent.com/automodule/bash/main/install_netdata.sh | bash

# install requirements for tfe
apt-get update

# Download all the software and files needed
apt-get -y install awscli
aws s3 cp s3://${tag_prefix}-software/${filename_license} /tmp/${filename_license}
aws s3 cp s3://${tag_prefix}-software/certificate_pem /tmp/certificate_pem
aws s3 cp s3://${tag_prefix}-software/issuer_pem /tmp/issuer_pem
aws s3 cp s3://${tag_prefix}-software/private_key_pem /tmp/server.key

# Create a full chain from the certificates
cat /tmp/certificate_pem >> /tmp/server.crt
cat /tmp/issuer_pem >> /tmp/server.crt

# create the configuration file for replicated installation
cat > /tmp/tfe_settings.json <<EOF
{
   "aws_instance_profile": {
        "value": "1"
    },
    "custom_image_tag": {
        "value": "custom-worker:latest"
    },
    "enc_password": {
        "value": "${tfe_password}"
    },
    "hairpin_addressing": {
        "value": "0"
    },
    "hostname": {
        "value": "${dns_hostname}.${dns_zonename}"
    },
    "pg_dbname": {
        "value": "${pg_dbname}"
    },
    "pg_netloc": {
        "value": "${pg_address}"
    },
    "pg_password": {
        "value": "${rds_password}"
    },
    "pg_user": {
        "value": "postgres"
    },
    "placement": {
        "value": "placement_s3"
    },
    "production_type": {
        "value": "external"
    },
    "s3_bucket": {
        "value": "${tfe_bucket}"
    },
    "s3_endpoint": {},
    "s3_region": {
        "value": "${region}"
    },
        "tbw_image": {
        "value": "custom_image"
    }
}
EOF


# replicated.conf file
cat > /etc/replicated.conf <<EOF
{
    "DaemonAuthenticationType":          "password",
    "DaemonAuthenticationPassword":      "${tfe_password}",
    "TlsBootstrapType":                  "server-path",
    "TlsBootstrapHostname":              "${dns_hostname}.${dns_zonename}",
    "TlsBootstrapCert":                  "/tmp/server.crt",
    "TlsBootstrapKey":                   "/tmp/server.key",
    "BypassPreflightChecks":             true,
    "ImportSettingsFrom":                "/tmp/tfe_settings.json",
    "LicenseFileLocation":               "/tmp/${filename_license}"
}
EOF

# cat > /tmp/docker/Dockerfile <<EOF
# # This Dockerfile builds the image used for the worker containers.
# FROM ubuntu:bionic

# # Install required software for Terraform Enterprise.
# RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
#     sudo unzip python python-pip daemontools git-core awscli ssh wget curl psmisc iproute2 openssh-client redis-tools netcat-openbsd ca-certificates

# # Include all necessary CA certificates.
# ADD server.crt /usr/local/share/ca-certificates/


# # Update the CA certificates bundle to include newly added CA certificates.
# RUN update-ca-certificates

# RUN apt-get update \
#     && apt-get install --no-install-recommends -y ca-certificates curl apt-transport-https lsb-release gnupg \
#     && curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null \
#     && AZ_REPO=\$(lsb_release -cs) \
#     && echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ \$AZ_REPO main" | tee /etc/apt/sources.list.d/azure-cli.list \
#     && apt-get update \
#     && apt-get install -y azure-cli
# EOF

# script that can be used to configure the environment easily for the first time
cat > /tmp/tfe_setup.sh <<EOF
#!/usr/bin/env bash

# only really needed when not using valid certificates
echo -n | openssl s_client -connect ${dns_hostname}.${dns_zonename}:443 | openssl x509 > tfe_certificate.crt
sudo cp tfe_certificate.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates

# We have to wait for TFE be fully functioning before we can continue
while true; do
    if curl -I "https://${dns_hostname}.${dns_zonename}/admin" 2>&1 | grep -w "200\|301" ; 
    then
        echo "TFE is up and running"
        echo "Will continue in 1 minutes with the final steps"
        sleep 60
        break
    else
        echo "TFE is not available yet. Please wait..."
        sleep 60
    fi
done

# get the admin token you can use to create the first user
ADMIN_TOKEN=\`sudo /usr/local/bin/replicated admin --tty=0 retrieve-iact | tr -d '\r'\`

# Create the first user called admin and get the token
TOKEN=\`curl --header "Content-Type: application/json" --request POST --data '{"username": "admin", "email": "${certificate_email}", "password": "${tfe_password}"}' \ --url https://${dns_hostname}.${dns_zonename}/admin/initial-admin-user?token=\$ADMIN_TOKEN | jq '.token' | tr -d '"'\`

# create the organization called test
curl \
  --header "Authorization: Bearer \$TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  --request POST \
  --data '{"data": { "type": "organizations", "attributes": {"name": "test", "email": "${certificate_email}"}}}' \
  https://${dns_hostname}.${dns_zonename}/api/v2/organizations

# Create a cli-driven workspace named test-custom-worker
curl \
  --header "Authorization: Bearer \$TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  --request POST \
  --data '{"data": {"attributes": {"name": "test-custom-worker", "resource-count": 0, "updated-at": "2017-11-29T19:18:09.976Z"}, "type": "workspaces"}}' \
  https://${dns_hostname}.${dns_zonename}/api/v2/organizations/test/workspaces
EOF

# Get the public IP of the instance
PUBLIC_IP=`curl http://169.254.169.254/latest/meta-data/public-ipv4`

pushd /var/tmp
curl -o install.sh https://install.terraform.io/ptfe/stable


if [ "${tfe_release_sequence}" ] ; then
  bash ./install.sh release-sequence=${tfe_release_sequence} no-proxy private-address=${tfe-private-ip} public-address=$PUBLIC_IP
else
  bash ./install.sh no-proxy private-address=${tfe-private-ip} public-address=$PUBLIC_IP
fi

replicatedctl params set ReleaseSequence --value '0'


# Docker customer worker
mkdir -p /tmp/docker
pushd /tmp/docker
aws s3 cp s3://${tag_prefix}-software/Dockerfile /tmp/docker/Dockerfile
echo -n | openssl s_client -connect ${dns_hostname}.${dns_zonename}:8800 | openssl x509 > tfe_certificate.crt

docker build -t custom-worker .



