#!/bin/bash

# Variables
DOMAIN="syndicate.vip"
MAIL_SERVER="mail.$DOMAIN"
DKIM_SELECTOR="default"
KEYCLOAK_VERSION="25.0.2"

# Stop and disable services
sudo systemctl stop postfix dovecot pdns opendkim keycloak
sudo systemctl disable postfix dovecot pdns opendkim keycloak

# Remove Keycloak service
sudo systemctl disable keycloak
sudo rm -f /etc/systemd/system/keycloak.service
sudo systemctl daemon-reload

# Remove Keycloak
sudo rm -rf /opt/keycloak
sudo rm -rf keycloak-${KEYCLOAK_VERSION}.tar.gz

# Remove Netbird VPN
sudo netbird down
sudo apt-get purge -y netbird
sudo rm /etc/apt/sources.list.d/netbird.list

# Remove DKIM keys and configuration
sudo rm -rf /etc/opendkim
sudo rm -f /etc/opendkim.conf /etc/default/opendkim

# Remove SSL certificates
sudo certbot delete --cert-name $MAIL_SERVER

# Remove Postfix and Dovecot configuration
sudo apt-get purge -y postfix dovecot-core dovecot-imapd dovecot-pop3d
sudo rm -rf /etc/postfix /etc/dovecot

# Remove MySQL database and user for PowerDNS
sudo mysql -u root -ppass <<EOF
DROP DATABASE powerdns;
DROP USER 'powerdns'@'localhost';
FLUSH PRIVILEGES;
EOF

# Remove PowerDNS configuration
sudo apt-get purge -y pdns-server pdns-backend-mysql
sudo rm -rf /etc/powerdns

# Remove any remaining packages installed by the script
sudo apt-get purge -y opendkim opendkim-tools certbot default-jdk
sudo apt-get autoremove -y

# Remove downloaded files
rm -f schema.mysql.sql

# Cleanup package lists
sudo apt-get clean

# Remove any remaining files or configurations created by the script
sudo rm -rf /etc/letsencrypt/live/$MAIL_SERVER /etc/letsencrypt/archive/$MAIL_SERVER /etc/letsencrypt/renewal/$MAIL_SERVER.conf

echo "Nuke script executed successfully. All configurations have been removed."
