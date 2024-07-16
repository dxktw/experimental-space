#!/bin/bash

# This script installs and configures a mail server using Postfix and Dovecot for the domain syndicate.vip, including SSL and DKIM setup.

# Set variables for DNS and mail server
DOMAIN="syndicate.vip"
MAIL_SERVER="mail.$DOMAIN"
DKIM_SELECTOR="default"

# Update system and install necessary packages
sudo apt update
sudo apt install -y postfix dovecot-core dovecot-imapd dovecot-pop3d certbot opendkim opendkim-tools

# Configure Postfix
sudo debconf-set-selections <<< "postfix postfix/mailname string $MAIL_SERVER"
sudo debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
sudo apt install -y postfix

sudo tee /etc/postfix/main.cf > /dev/null <<EOL
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
sudo tee /etc/dovecot/dovecot.conf > /dev/null <<EOL
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

sudo systemctl restart opendkim
sudo systemctl restart postfix

# Configure DNS records for DKIM, SPF, and DMARC (assuming PowerDNS)
echo "Configure the following DNS records:"
echo "DKIM: Host: $DKIM_SELECTOR._domainkey.$DOMAIN, Type: TXT, Value: (paste the contents of $DKIM_SELECTOR.txt here)"
echo "SPF: Host: $DOMAIN, Type: TXT, Value: 'v=spf1 mx ~all'"
echo "DMARC: Host: _dmarc.$DOMAIN, Type: TXT, Value: 'v=DMARC1; p=none; rua=mailto:postmaster@$DOMAIN'"

echo "Mail server setup completed successfully."
