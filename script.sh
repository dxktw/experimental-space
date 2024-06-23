#!/bin/bash

# Source the OpenStack RC file to set environment variables
source ./openrc.sh

# Variables for OpenStack and domain
DOMAIN="syndicate.vip"
MAIL_SERVER="mail.$DOMAIN"
DKIM_SELECTOR="default"
OS_FLAVOR_ID="58ca36f0-7ffa-42e6-aea1-1d4b0471d18a"  # Replace with the desired flavor ID

# Create OpenStack Instances
openstack server create --flavor $OS_FLAVOR_ID --image ubuntu-20.04 --nic net-id=$OS_NETWORK_ID --security-group default --key-name mykey ansible-host
ANSIBLE_HOST_IP=$(openstack server list --name ansible-host -f value -c Networks | awk -F'=' '{print $2}')

# Check if the instance was created successfully
if [ -z "$ANSIBLE_HOST_IP" ]; then
  echo "Failed to create OpenStack instance."
  exit 1
fi

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
ssh -o StrictHostKeyChecking=no -i /path/to/private_key_file ubuntu@$ANSIBLE_HOST_IP <<EOF
curl -fsSL https://packages.netbird.io/install.sh | sudo bash
sudo netbird up
EOF

echo "Setup completed successfully."
