#!/bin/bash

# Variables for OpenStack and domain
OS_AUTH_URL="https://keystone.rumble.cloud"
OS_PROJECT_NAME="orchestration-syndicate-beta"
OS_USERNAME="01hkrw9056f1q8vgqx19pc4pt7"
OS_PASSWORD="8e3cdcedd7125e86c919509bcc2121c502363e1af4a949003114bf3cb8674430"
OS_USER_DOMAIN_NAME="Default"
OS_PROJECT_DOMAIN_NAME="Default"
OS_REGION_NAME="us-east-1"
OS_INTERFACE="public"
OS_IDENTITY_API_VERSION=3
OS_APPLICATION_CREDENTIAL_ID="1e7cebea32a0411bbb47e3b08e291f5f"
OS_APPLICATION_CREDENTIAL_SECRET="YObyM_BY4jPS2V7Eu3iwpq50FH_MbRI2197J_bMaJh79373wP2sjJYPpCcKo41snIMlGMWyWsvsPNNNeBgzIuA"
OS_NETWORK_ID="ffb9d04d-64f4-43e7-bace-0a5fa5935b95"
FLAVOR_ID="58ca36f0-7ffa-42e6-aea1-1d4b0471d18a" # 4GB RAM - 2 vCPU flavor ID
DOMAIN="syndicate.vip"
MAIL_SERVER="mail.$DOMAIN"
DKIM_SELECTOR="default"
MAIL_SERVER_IP="207.5.197.59"

# Configure OpenStack CLI
mkdir -p ~/.config/openstack
cat > ~/.config/openstack/clouds.yaml <<EOL
clouds:
  openstack:
    auth:
      auth_url: $OS_AUTH_URL
      application_credential_id: $OS_APPLICATION_CREDENTIAL_ID
      application_credential_secret: $OS_APPLICATION_CREDENTIAL_SECRET
      user_domain_name: $OS_USER_DOMAIN_NAME
      project_domain_name: $OS_PROJECT_DOMAIN_NAME
    region_name: $OS_REGION_NAME
    interface: $OS_INTERFACE
    identity_api_version: $OS_IDENTITY_API_VERSION
    auth_type: v3applicationcredential
EOL

# Source OpenStack RC File
source <(cat <<EOF
export OS_AUTH_URL=$OS_AUTH_URL
export OS_PROJECT_NAME=$OS_PROJECT_NAME
export OS_USERNAME=$OS_USERNAME
export OS_PASSWORD=$OS_PASSWORD
export OS_USER_DOMAIN_NAME=$OS_USER_DOMAIN_NAME
export OS_PROJECT_DOMAIN_NAME=$OS_PROJECT_DOMAIN_NAME
export OS_REGION_NAME=$OS_REGION_NAME
export OS_INTERFACE=$OS_INTERFACE
export OS_IDENTITY_API_VERSION=$OS_IDENTITY_API_VERSION
export OS_APPLICATION_CREDENTIAL_ID=$OS_APPLICATION_CREDENTIAL_ID
export OS_APPLICATION_CREDENTIAL_SECRET=$OS_APPLICATION_CREDENTIAL_SECRET
EOF
)

# Create OpenStack Instances
openstack server create --flavor $FLAVOR_ID --image ubuntu-20.04 --nic net-id=$OS_NETWORK_ID --security-group default --key-name mykey ansible-host
ANSIBLE_HOST_IP=$(openstack server list --name ansible-host -f value -c Networks | awk -F'=' '{print $2}')

# Wait for the server to be active
while [[ "$(openstack server show ansible-host -f value -c status)" != "ACTIVE" ]]; do
  sleep 5
done

# SSH into Ansible Host and configure it
ssh -o StrictHostKeyChecking=no -i /path/to/private_key_file ubuntu@$ANSIBLE_HOST_IP <<EOF
sudo apt update
sudo apt install -y ansible postfix dovecot-core dovecot-imapd dovecot-pop3d certbot opendkim opendkim-tools

# Configure Postfix
sudo debconf-set-selections <<< "postfix postfix/mailname string $MAIL_SERVER"
sudo debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
sudo apt install -y postfix

sudo tee -a /etc/postfix/main.cf > /dev/null <<EOL
myhostname = $MAIL_SERVER
mydomain = $DOMAIN
myorigin = \$mydomain
inet_interfaces = all
mydestination = \$myhostname, localhost.\$mydomain, localhost
relay_domains = *
home_mailbox = Maildir/
smtpd_banner = \$myhostname ESMTP \$mail_name
biff = no
append_dot_mydomain = no
readme_directory = no
compatibility_level = 2
smtpd_tls_cert_file=/etc/letsencrypt/live/$MAIL_SERVER/fullchain.pem
smtpd_tls_key_file=/etc/letsencrypt/live/$MAIL_SERVER/privkey.pem
smtpd_use_tls=yes
smtpd_tls_auth_only = yes
smtp_tls_security_level = may
smtp_tls_loglevel = 1
smtpd_tls_loglevel = 1
smtpd_tls_received_header = yes
smtpd_tls_session_cache_timeout = 3600s
smtpd_tls_session_cache_database = btree:\${data_directory}/smtpd_scache
smtp_tls_session_cache_database = btree:\${data_directory}/smtp_scache
milter_protocol = 6
milter_default_action = accept
smtpd_milters = inet:localhost:8891
non_smtpd_milters = inet:localhost:8891
EOL

sudo systemctl restart postfix

# Configure Dovecot
sudo tee -a /etc/dovecot/dovecot.conf > /dev/null <<EOL
protocols = imap pop3 lmtp
mail_location = maildir:~/Maildir
namespace inbox {
  inbox = yes
}
auth_mechanisms = plain login
userdb {
  driver = passwd
}
passdb {
  driver = pam
}
service auth {
  unix_listener /var/spool/postfix/private/auth {
    mode = 0666
  }
}
EOL

sudo systemctl restart dovecot

# Set up SSL certificates using Let's Encrypt
sudo apt install -y certbot
sudo certbot certonly --standalone -d $MAIL_SERVER

# Set up DKIM
sudo apt install -y opendkim opendkim-tools
sudo tee /etc/opendkim.conf > /dev/null <<EOL
Syslog yes
UMask 002
Domain $DOMAIN
Selector $DKIM_SELECTOR
KeyFile /etc/opendkim/keys/$DOMAIN.private
Socket inet:8891@localhost
EOL

sudo mkdir -p /etc/opendkim/keys
sudo opendkim-genkey -s $DKIM_SELECTOR -d $DOMAIN
sudo mv $DKIM_SELECTOR.private /etc/opendkim/keys/$DOMAIN.private
sudo chown opendkim:opendkim /etc/opendkim/keys/$DOMAIN.private

sudo tee /etc/default/opendkim > /dev/null <<EOL
SOCKET="inet:8891@localhost"
EOL

sudo tee -a /etc/postfix/main.cf > /dev/null <<EOL
milter_protocol = 6
milter_default_action = accept
smtpd_milters = inet:localhost:8891
non_smtpd_milters = inet:localhost:8891
EOL

sudo systemctl restart opendkim
sudo systemctl restart postfix
EOF

# Install and Configure Netbird VPN on the Ansible Host
ssh -o StrictHostKeyChecking=no -i /path/to/private_key_file ubuntu@$ANSIBLE_HOST_IP <<EOF
curl -fsSL https://packages.netbird.io/install.sh | sudo bash
sudo netbird up
EOF

echo "Setup completed successfully."
