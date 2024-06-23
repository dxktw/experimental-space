#!/bin/bash

# Set variables for OpenStack
OS_AUTH_URL="https://keystone.rumble.cloud"
OS_PROJECT_NAME="Orchestration"
OS_USERNAME="01hkrw9056f1q8vgqx19pc4pt7"
OS_PASSWORD="8e3cdcedd7125e86c919509bcc2121c502363e1af4a949003114bf3cb8674430"
OS_NETWORK_ID="ffb9d04d-64f4-43e7-bace-0a5fa5935b95"
OS_REGION_NAME="us-east-1"
OS_APPLICATION_CREDENTIAL_ID="1e7cebea32a0411bbb47e3b08e291f5f"
OS_APPLICATION_CREDENTIAL_SECRET="YObyM_BY4jPS2V7Eu3iwpq50FH_MbRI2197J_bMaJh79373wP2sjJYPpCcKo41snIMlGMWyWsvsPNNNeBgzIuA"

# Set variables for DNS and mail server
DOMAIN="syndicate.vip"
MAIL_SERVER="mail.$DOMAIN"
DKIM_SELECTOR="default"

# Clear out any previously sourced OpenStack ENV
for key in $( set | awk '{FS="="}  /^OS_/ {print $1}' ); do unset $key ; done

# Set OpenStack environment variables
export OS_AUTH_TYPE=v3applicationcredential
export OS_AUTH_URL=$OS_AUTH_URL
export OS_APPLICATION_CREDENTIAL_ID=$OS_APPLICATION_CREDENTIAL_ID
export OS_APPLICATION_CREDENTIAL_SECRET=$OS_APPLICATION_CREDENTIAL_SECRET
export OS_INTERFACE=public
export OS_IDENTITY_API_VERSION=3
export OS_REGION_NAME=$OS_REGION_NAME

# Install necessary packages for OpenStack CLI
sudo apt update
sudo apt install -y python3-openstackclient python3-octaviaclient

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
source <(echo "
export OS_AUTH_TYPE=v3applicationcredential
export OS_AUTH_URL=$OS_AUTH_URL
export OS_APPLICATION_CREDENTIAL_ID=$OS_APPLICATION_CREDENTIAL_ID
export OS_APPLICATION_CREDENTIAL_SECRET=$OS_APPLICATION_CREDENTIAL_SECRET
export OS_INTERFACE=public
export OS_IDENTITY_API_VERSION=3
export OS_REGION_NAME=$OS_REGION_NAME
")

# Create OpenStack Instances
openstack server create --flavor m1.small --image ubuntu-20.04 --nic net-id=$OS_NETWORK_ID --security-group default ansible-host
ANSIBLE_HOST_IP=$(openstack server list --name ansible-host -f value -c Networks | awk -F'=' '{print $2}')
