#!/bin/bash

# This script installs and configures PowerDNS with a MySQL backend and sets up the necessary DNS records for the domain syndicate.vip.

# Set variables
MYSQL_ROOT_PASSWORD="8e3cdcedd7125e86c919509bcc2121c502363e1af4a949003114bf3cb8674430"
PDNS_DB_PASSWORD=""
DOMAIN="syndicate.vip"
MAIL_SERVER="mail.$DOMAIN"
MAIL_SERVER_IP=""
DKIM_SELECTOR="default"

# Update system and install necessary packages
sudo apt update
sudo apt upgrade -y
sudo apt install -y pdns-server pdns-backend-mysql mysql-server

# Configure MySQL
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

echo "PowerDNS installation and configuration completed successfully."
echo "DKIM keys generated and DNS records for DKIM, SPF, and DMARC have been added."
