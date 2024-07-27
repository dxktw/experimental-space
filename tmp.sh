#!/bin/bash

# Variables
DOMAIN="syndicate.vip"
MAIL_SERVER="mail.$DOMAIN"
DKIM_SELECTOR="default"
MAIL_SERVER_IP="207.5.194.102"
KEYCLOAK_USER="admin"
KEYCLOAK_PASSWORD="admin"
KEYCLOAK_VERSION="25.0.2"  # Update to the latest stable version
NETBIRD_REPO="https://packages.netbird.io/debian/netbird-release.key"

# Update system and install necessary packages
sudo apt update && sudo apt upgrade -y
sudo apt install -y postfix dovecot-core dovecot-imapd dovecot-pop3d certbot pdns-server pdns-backend-mysql mysql-server opendkim opendkim-tools default-jdk

echo -e "\n\n\n--------------------------------------------------------------------------\n\n\n"
sleep 100

# Configure MySQL for PowerDNS
sudo mysql -u root -ppass <<EOF
CREATE DATABASE powerdns;
CREATE USER 'powerdns'@'localhost' IDENTIFIED BY pdnspass;
GRANT ALL PRIVILEGES ON powerdns.* TO 'powerdns'@'localhost';
FLUSH PRIVILEGES;
EOF

echo -e "\n\n\n--------------------------------------------------------------------------\n\n\n"
sleep 100

# Download and import PowerDNS schema
wget https://raw.githubusercontent.com/PowerDNS/pdns/master/modules/gmysqlbackend/schema.mysql.sql
sudo mysql -u root -ppass powerdns < schema.mysql.sql

echo -e "\n\n\n--------------------------------------------------------------------------\n\n\n"
sleep 100

# Configure PowerDNS
sudo tee /etc/powerdns/pdns.conf > /dev/null <<EOL
launch=gmysql
gmysql-host=localhost
gmysql-user=powerdns
gmysql-password=${PDNS_DB_PASSWORD}
gmysql-dbname=powerdns
EOL

echo -e "\n\n\n--------------------------------------------------------------------------\n\n\n"
sleep 100

# Restart and enable PowerDNS
sudo systemctl restart pdns
sudo systemctl enable pdns

echo -e "\n\n\n--------------------------------------------------------------------------\n\n\n"
sleep 100

# Add DNS records
sudo mysql -u root -ppass <<EOF
USE powerdns;
INSERT INTO domains (name, type) VALUES ('${DOMAIN}', 'NATIVE');
INSERT INTO records (domain_id, name, type, content, ttl, prio) VALUES ((SELECT id FROM domains WHERE name='${DOMAIN}'), '${DOMAIN}', 'SOA', 'ns1.${DOMAIN} hostmaster.${DOMAIN} 1 3600 1200 604800 3600', 86400, NULL);
INSERT INTO records (domain_id, name, type, content, ttl, prio) VALUES ((SELECT id FROM domains WHERE name='${DOMAIN}'), '${DOMAIN}', 'NS', 'ns1.${DOMAIN}', 86400, NULL);
INSERT INTO records (domain_id, name, type, content, ttl, prio) VALUES ((SELECT id FROM domains WHERE name='${DOMAIN}'), '${DOMAIN}', 'MX', '${MAIL_SERVER}', 86400, 10);
INSERT INTO records (domain_id, name, type, content, ttl, prio) VALUES ((SELECT id FROM domains WHERE name='${DOMAIN}'), '${MAIL_SERVER}', 'A', '${MAIL_SERVER_IP}', 86400, NULL);

echo -e "\n\n\n--------------------------------------------------------------------------\n\n\n"
sleep 100

INSERT INTO domains (name, type) VALUES ('connect.syndicate.vip', 'NATIVE');
INSERT INTO records (domain_id, name, type, content, ttl, prio) VALUES ((SELECT id FROM domains WHERE name='connect.syndicate.vip'), 'connect.syndicate.vip', 'A', '${MAIL_SERVER_IP}', 86400, NULL);

echo -e "\n\n\n--------------------------------------------------------------------------\n\n\n"
sleep 100

INSERT INTO domains (name, type) VALUES ('vpn.syndicate.vip', 'NATIVE');
INSERT INTO records (domain_id, name, type, content, ttl, prio) VALUES ((SELECT id FROM domains WHERE name='vpn.syndicate.vip'), 'vpn.syndicate.vip', 'A', '${MAIL_SERVER_IP}', 86400, NULL);

echo -e "\n\n\n--------------------------------------------------------------------------\n\n\n"
sleep 100

INSERT INTO domains (name, type) VALUES ('conductor.orchestra.private', 'NATIVE');
INSERT INTO records (domain_id, name, type, content, ttl, prio) VALUES ((SELECT id FROM domains WHERE name='conductor.orchestra.private'), 'conductor.orchestra.private', 'A', '${MAIL_SERVER_IP}', 86400, NULL);

echo -e "\n\n\n--------------------------------------------------------------------------\n\n\n"
sleep 100

INSERT INTO domains (name, type) VALUES ('netbird.syndicate.vip', 'NATIVE');
INSERT INTO records (domain_id, name, type, content, ttl, prio) VALUES ((SELECT id FROM domains WHERE name='netbird.syndicate.vip'), 'netbird.syndicate.vip', 'A', '${MAIL_SERVER_IP}', 86400, NULL);

echo -e "\n\n\n--------------------------------------------------------------------------\n\n\n"
sleep 100

INSERT INTO domains (name, type) VALUES ('keycloak.syndicate.vip', 'NATIVE');
INSERT INTO records (domain_id, name, type, content, ttl, prio) VALUES ((SELECT id FROM domains WHERE name='keycloak.syndicate.vip'), 'keycloak.syndicate.vip', 'A', '${MAIL_SERVER_IP}', 86400, NULL);
EOF

echo -e "\n\n\n--------------------------------------------------------------------------\n\n\n"
sleep 100

# Generate DKIM keys and add DNS records for DKIM, SPF, and DMARC
opendkim-genkey -s ${DKIM_SELECTOR} -d ${DOMAIN}
sudo mkdir -p /etc/opendkim/keys
sudo mv ${DKIM_SELECTOR}.private /etc/opendkim/keys/${DOMAIN}.private
sudo chown opendkim:opendkim /etc/opendkim/keys/${DOMAIN}.private

echo -e "\n\n\n--------------------------------------------------------------------------\n\n\n"
sleep 100

DKIM_RECORD=$(cat ${DKIM_SELECTOR}.txt)

echo -e "\n\n\n--------------------------------------------------------------------------\n\n\n"
sleep 100

sudo mysql -u root -ppass <<EOF
USE powerdns;
INSERT INTO records (domain_id, name, type, content, ttl, prio) VALUES ((SELECT id FROM domains WHERE name='${DOMAIN}'), '${DKIM_SELECTOR}._domainkey.${DOMAIN}', 'TXT', '${DKIM_RECORD}', 86400, NULL);
INSERT INTO records (domain_id, name, type, content, ttl, prio) VALUES ((SELECT id FROM domains WHERE name='${DOMAIN}'), '${DOMAIN}', 'TXT', 'v=spf1 mx ~all', 86400, NULL);
INSERT INTO records (domain_id, name, type, content, ttl, prio) VALUES ((SELECT id FROM domains WHERE name='${DOMAIN}'), '_dmarc.${DOMAIN}', 'TXT', 'v=DMARC1; p=none; rua=mailto:postmaster@${DOMAIN}', 86400, NULL);
EOF

echo -e "\n\n\n--------------------------------------------------------------------------\n\n\n"
sleep 100

# Configure Postfix
sudo debconf-set-selections <<< "postfix postfix/mailname string $MAIL_SERVER"
sudo debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
sudo apt install -y postfix

echo -e "\n\n\n--------------------------------------------------------------------------\n\n\n"
sleep 100

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

echo -e "\n\n\n--------------------------------------------------------------------------\n\n\n"
sleep 100

sudo systemctl restart postfix

echo -e "\n\n\n--------------------------------------------------------------------------\n\n\n"
sleep 100

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

echo -e "\n\n\n--------------------------------------------------------------------------\n\n\n"
sleep 100

sudo systemctl restart dovecot

echo -e "\n\n\n--------------------------------------------------------------------------\n\n\n"
sleep 100

# Set up SSL certificates using Let's Encrypt
sudo certbot certonly --standalone -d $MAIL_SERVER

echo -e "\n\n\n--------------------------------------------------------------------------\n\n\n"
sleep 100

# Set up DKIM
sudo tee /etc/opendkim.conf > /dev/null <<EOL
Syslog yes
UMask 002
Domain $DOMAIN
Selector $DKIM_SELECTOR
KeyFile /etc/opendkim/keys/$DOMAIN.private
Socket inet:8891@localhost
EOL

echo -e "\n\n\n--------------------------------------------------------------------------\n\n\n"
sleep 100

sudo tee /etc/default/opendkim > /dev/null <<EOL
SOCKET="inet:8891@localhost"
EOL

echo -e "\n\n\n--------------------------------------------------------------------------\n\n\n"
sleep 100

sudo systemctl restart opendkim
sudo systemctl restart postfix

echo -e "\n\n\n--------------------------------------------------------------------------\n\n\n"
sleep 100

# Install and Configure Netbird VPN
wget -qO- $NETBIRD_REPO | sudo apt-key add -
echo "deb https://packages.netbird.io/debian/ netbird main" | sudo tee /etc/apt/sources.list.d/netbird.list
sudo apt update
sudo apt install -y netbird

echo -e "\n\n\n--------------------------------------------------------------------------\n\n\n"
sleep 100

# Start Netbird and obtain a setup key from the admin panel
sudo netbird up --setup-key YOUR_SETUP_KEY

echo -e "\n\n\n--------------------------------------------------------------------------\n\n\n"
sleep 100

# Install Keycloak
wget https://github.com/keycloak/keycloak/releases/download/${KEYCLOAK_VERSION}/keycloak-${KEYCLOAK_VERSION}.tar.gz
tar -xvzf keycloak-${KEYCLOAK_VERSION}.tar.gz
sudo mv keycloak-${KEYCLOAK_VERSION} /opt/keycloak

echo -e "\n\n\n--------------------------------------------------------------------------\n\n\n"
sleep 100

sudo /opt/keycloak/bin/kc.sh start-dev --http-port=8080 &

echo -e "\n\n\n--------------------------------------------------------------------------\n\n\n"
sleep 100

# Configuring Keycloak as a service
sudo tee /etc/systemd/system/keycloak.service > /dev/null <<EOL
[Unit]
Description=Keycloak Service
After=network.target

echo -e "\n\n\n--------------------------------------------------------------------------\n\n\n"
sleep 100

[Service]
Type=simple
ExecStart=/opt/keycloak/bin/kc.sh start --http-port=8080
User=keycloak
Group=keycloak
Restart=always

echo -e "\n\n\n--------------------------------------------------------------------------\n\n\n"
sleep 100

[Install]
WantedBy=multi-user.target
EOL

echo -e "\n\n\n--------------------------------------------------------------------------\n\n\n"
sleep 100

sudo systemctl daemon-reload
sudo systemctl enable keycloak
sudo systemctl start keycloak

echo -e "\n\n\n--------------------------------------------------------------------------\n\n\n"
sleep 100

echo "Setup completed successfully."
