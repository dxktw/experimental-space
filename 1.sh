#!/bin/bash

# This script configures an OpenStack environment, sets up instances, and installs Ansible and a mail server with SSL and DKIM on the Ansible host.

# Set variables for OpenStack
OS_AUTH_URL="https://docs.rumble.cloud/"
OS_PROJECT_NAME="Orchestration"
OS_USERNAME="01hkrw9056f1q8vgqx19pc4pt7"
OS_PASSWORD="8e3cdcedd7125e86c919509bcc2121c502363e1af4a949003114bf3cb8674430"
OS_NETWORK_ID=""

# Set variables for DNS and mail server
DOMAIN="syndicate.vip"
MAIL_SERVER="mail.$DOMAIN"
DKIM_SELECTOR="default"

# Install necessary packages
sudo apt update
sudo apt install -y python3-openstackclient python3-octaviaclient ansible postfix dovecot-core dovecot-imapd dovecot-pop3d certbot opendkim opendkim-tools

# Configure OpenStack CLI
mkdir -p ~/.config/openstack
cat > ~/.config/openstack/clouds.yaml <<EOL
clouds:
  my_cloud:
    auth:
      auth_url: $OS_AUTH_URL
      username: $OS_USERNAME
      password: $OS_PASSWORD
      project_name: $OS_PROJECT_NAME
      user_domain_name: "Default"
      project_domain_name: "Default"
EOL

# Source OpenStack RC File
source /path/to/your/openrc.sh

# Create OpenStack Instances
openstack server create --flavor m1.small --image ubuntu-20.04 --nic net-id=$OS_NETWORK_ID --security-group default ansible-host
ANSIBLE_HOST_IP=$(openstack server list --name ansible-host -f value -c Networks | awk -F'=' '{print $2}')

# Install Ansible on the Ansible Host
ssh ubuntu@$ANSIBLE_HOST_IP <<EOF
sudo apt update
sudo apt install -y ansible
EOF

# Configure Mail Server (Postfix, Dovecot)
ssh ubuntu@$ANSIBLE_HOST_IP <<EOF
sudo debconf-set-selections <<< "postfix postfix/mailname string $MAIL_SERVER"
sudo debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
sudo apt install -y postfix dovecot-core dovecot-imapd dovecot-pop3d

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
EOL

sudo systemctl restart postfix

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
EOF

# Set up SSL certificates using Let's Encrypt
ssh ubuntu@$ANSIBLE_HOST_IP <<EOF
sudo apt install -y certbot
sudo certbot certonly --standalone -d $MAIL_SERVER
sudo tee -a /etc/postfix/main.cf > /dev/null <<EOL
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
EOL

sudo systemctl restart postfix
EOF

# Set up DKIM
ssh ubuntu@$ANSIBLE_HOST_IP <<EOF
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

sudo tee -a /etc/default/opendkim > /dev/null <<EOL
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
ssh ubuntu@$ANSIBLE_HOST_IP <<EOF
curl -fsSL https://packages.netbird.io/install.sh | sudo bash
sudo netbird up
EOF

echo "Setup completed successfully."
