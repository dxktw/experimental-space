#!/bin/bash

# Set variables for DNS and mail server
DOMAIN="syndicate.vip"
MAIL_SERVER="mail.$DOMAIN"
DKIM_SELECTOR="default"
MYSQL_ROOT_PASSWORD="8e3cdcedd7125e86c919509bcc2121c502363e1af4a949003114bf3cb8674430"
PDNS_DB_PASSWORD="sGj4]%C^"
MAIL_SERVER_IP="207.5.195.27"

# Update system and install necessary packages
sudo apt update
sudo apt install -y postfix dovecot-core dovecot-imapd dovecot-pop3d certbot pdns-server pdns-backend-mysql mysql-server opendkim opendkim-tools netbird default-jdk

# Configure MySQL for PowerDNS
sudo mysql -u root -p${MYSQL_ROOT_PASSWORD} <<EOF
CREATE DATABASE powerdns;
CREATE USER 'powerdns'@'localhost' IDENTIFIED BY '${PDNS_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON powerdns.* TO 'powerdns'@'localhost';
FLUSH PRIVILEGES;
EXIT;
EOF

# Download and import PowerDNS schema
wget https://raw.githubusercontent.com/PowerDNS/pdns/master/modules/gmysqlbackend/schema.mysql.sql
sudo mysql -u root -p${MYSQL_ROOT_PASSWORD} powerdns < schema.mysql.sql

# Configure PowerDNS
sudo tee /etc/powerdns/pdns.conf > /dev/null <<EOL
launch=gmysql
gmysql-host=localhost
gmysql-user=powerdns
gmysql-password=${PDNS_DB_PASSWORD}
gmysql-dbname=powerdns
EOL

# Restart and enable PowerDNS
sudo systemctl restart pdns
sudo systemctl enable pdns

# Add DNS records
sudo mysql -u root -p${MYSQL_ROOT_PASSWORD} <<EOF
USE powerdns;
INSERT INTO domains (name, type) VALUES ('${DOMAIN}', 'NATIVE');
INSERT INTO records (domain_id, name, type, content, ttl, prio) VALUES (LAST_INSERT_ID(), '${DOMAIN}', 'SOA', 'ns1.${DOMAIN} hostmaster.${DOMAIN} 1 3600 1200 604800 3600', 86400, NULL);
INSERT INTO records (domain_id, name, type, content, ttl, prio) VALUES (LAST_INSERT_ID(), '${DOMAIN}', 'NS', 'ns1.${DOMAIN}', 86400, NULL);
INSERT INTO records (domain_id, name, type, content, ttl, prio) VALUES (LAST_INSERT_ID(), '${DOMAIN}', 'MX', '${MAIL_SERVER}', 86400, 10);
INSERT INTO records (domain_id, name, type, content, ttl, prio) VALUES (LAST_INSERT_ID(), '${MAIL_SERVER}', 'A', '${MAIL_SERVER_IP}', 86400, NULL);
EOF

# Generate DKIM keys and add DNS records for DKIM, SPF, and DMARC
opendkim-genkey -s ${DKIM_SELECTOR} -d ${DOMAIN}
sudo mkdir -p /etc/opendkim/keys
sudo mv ${DKIM_SELECTOR}.private /etc/opendkim/keys/${DOMAIN}.private
sudo chown opendkim:opendkim /etc/opendkim/keys/${DOMAIN}.private

DKIM_RECORD=$(cat ${DKIM_SELECTOR}.txt)

sudo mysql -u root -p${MYSQL_ROOT_PASSWORD} <<EOF
USE powerdns;
INSERT INTO records (domain_id, name, type, content, ttl, prio) VALUES ((SELECT id FROM domains WHERE name='${DOMAIN}'), '${DKIM_SELECTOR}._domainkey.${DOMAIN}', 'TXT', '${DKIM_RECORD}', 86400, NULL);
INSERT INTO records (domain_id, name, type, content, ttl, prio) VALUES ((SELECT id FROM domains WHERE name='${DOMAIN}'), '${DOMAIN}', 'TXT', 'v=spf1 mx ~all', 86400, NULL);
INSERT INTO records (domain_id, name, type, content, ttl, prio) VALUES ((SELECT id FROM domains WHERE name='${DOMAIN}'), '_dmarc.${DOMAIN}', 'TXT', 'v=DMARC1; p=none; rua=mailto:postmaster@${DOMAIN}', 86400, NULL);
EOF

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
sudo certbot certonly --standalone -d $MAIL_SERVER

# Set up DKIM
sudo tee /etc/opendkim.conf > /dev/null <<EOL
Syslog yes
UMask 002
Domain $DOMAIN
Selector $DKIM_SELECTOR
KeyFile /etc/opendkim/keys/$DOMAIN.private
Socket inet:8891@localhost
EOL

sudo tee /etc/default/opendkim > /dev/null <<EOL
SOCKET="inet:8891@localhost"
EOL

sudo systemctl restart opendkim
sudo systemctl restart postfix

# Install and Configure Netbird VPN
curl -fsSL https://packages.netbird.io/install.sh | sudo bash
sudo netbird up

# Install Keycloak
wget https://github.com/keycloak/keycloak/releases/download/11.0.2/keycloak-11.0.2.tar.gz
tar -xvzf keycloak-11.0.2.tar.gz
sudo mv keycloak-11.0.2 /opt/keycloak

sudo /opt/keycloak/bin/add-user-keycloak.sh -u admin -p admin

sudo tee /etc/systemd/system/keycloak.service > /dev/null <<EOL
[Unit]
Description=Keycloak Service
After=network.target

[Service]
Type=simple
User=keycloak
Group=keycloak
ExecStart=/opt/keycloak/bin/standalone.sh -b 0.0.0.0
Restart=always

[Install]
WantedBy=multi-user.target
EOL

sudo systemctl daemon-reload
sudo systemctl enable keycloak
sudo systemctl start keycloak

echo "Setup completed successfully."

