#!/bin/bash

# Variables for OpenStack and domain
OS_AUTH_URL="https://keystone.rumble.cloud"
OS_PROJECT_NAME="Orchestration"
OS_USERNAME="01hkrw9056f1q8vgqx19pc4pt7"
OS_PASSWORD="8e3cdcedd7125e86c919509bcc2121c502363e1af4a949003114bf3cb8674430"
OS_REGION_NAME="us-east-1"
OS_NETWORK_ID="ffb9d04d-64f4-43e7-bace-0a5fa5935b95"
ANSIBLE_HOST_FLAVOR="58ca36f0-7ffa-42e6-aea1-1d4b0471d18a"
MAIL_SERVER_FLAVOR="be1edaa1-2048-425e-b047-70632e487b20"
DOMAIN="syndicate.vip"
MAIL_SERVER="mail.$DOMAIN"
DKIM_SELECTOR="default"
MYSQL_ROOT_PASSWORD="8e3cdcedd7125e86c919509bcc2121c502363e1af4a949003114bf3cb8674430"
PDNS_DB_PASSWORD="secure_password_here"
MAIL_SERVER_IP="207.5.197.59"

# Clear out any previously sourced OpenStack ENV
for key in $( set | awk '{FS="="}  /^OS_/ {print $1}' ); do unset $key ; done

export OS_AUTH_TYPE=v3applicationcredential
export OS_AUTH_URL=$OS_AUTH_URL
export OS_APPLICATION_CREDENTIAL_ID="1e7cebea32a0411bbb47e3b08e291f5f"
export OS_APPLICATION_CREDENTIAL_SECRET="YObyM_BY4jPS2V7Eu3iwpq50FH_MbRI2197J_bMaJh79373wP2sjJYPpCcKo41snIMlGMWyWsvsPNNNeBgzIuA"
export OS_INTERFACE=public
export OS_IDENTITY_API_VERSION=3
export OS_REGION_NAME=$OS_REGION_NAME

# Install necessary packages
sudo apt update
sudo apt install -y python3-openstackclient python3-octaviaclient ansible

# Configure OpenStack CLI
mkdir -p ~/.config/openstack
cat > ~/.config/openstack/clouds.yaml <<EOL
clouds:
  openstack:
    auth:
      auth_url: $OS_AUTH_URL
      application_credential_id: $OS_APPLICATION_CREDENTIAL_ID
      application_credential_secret: $OS_APPLICATION_CREDENTIAL_SECRET
    region_name: $OS_REGION_NAME
    interface: "public"
    identity_api_version: 3
    auth_type: "v3applicationcredential"
EOL

# Source OpenStack RC File
export OS_CLOUD=openstack

# Create OpenStack Instances
openstack server create --flavor $ANSIBLE_HOST_FLAVOR --image ubuntu-20.04 --nic net-id=$OS_NETWORK_ID --security-group default ansible-host
ANSIBLE_HOST_IP=$(openstack server list --name ansible-host -f value -c Networks | awk -F'=' '{print $2}')

openstack server create --flavor $MAIL_SERVER_FLAVOR --image ubuntu-20.04 --nic net-id=$OS_NETWORK_ID --security-group default mail-server
MAIL_SERVER_IP=$(openstack server list --name mail-server -f value -c Networks | awk -F'=' '{print $2}')

# Wait for instances to be ready
sleep 60
