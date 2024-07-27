#!/bin/bash

sudo mysql -u root -p${MYSQL_ROOT_PASSWORD} <<EOF
USE powerdns;

-- Public domains
INSERT INTO domains (name, type) VALUES ('syndicate.vip', 'NATIVE');
INSERT INTO records (domain_id, name, type, content, ttl, prio) VALUES 
  (LAST_INSERT_ID(), 'syndicate.vip', 'SOA', 'ns1.syndicate.vip hostmaster.syndicate.vip 1 3600 1200 604800 3600', 86400, NULL),
  (LAST_INSERT_ID(), 'syndicate.vip', 'NS', 'ns1.syndicate.vip', 86400, NULL),
  (LAST_INSERT_ID(), 'mail.syndicate.vip', 'A', '${MAIL_SERVER_IP}', 86400, NULL),
  (LAST_INSERT_ID(), 'auth.syndicate.vip', 'A', '${KEYCLOAK_SERVER_IP}', 86400, NULL);

-- Internal domains
INSERT INTO domains (name, type) VALUES ('orchestra.private', 'NATIVE');
INSERT INTO records (domain_id, name, type, content, ttl, prio) VALUES 
  (LAST_INSERT_ID(), 'conductor.orchestra.private', 'A', '${PDNS_ROOT_IP}', 86400, NULL),
  (LAST_INSERT_ID(), 'dns1.company.corp', 'A', '${DNS1_IP}', 86400, NULL),
  (LAST_INSERT_ID(), 'dns2.company.corp', 'A', '${DNS2_IP}', 86400, NULL),
  (LAST_INSERT_ID(), 'keycloak.syndicate.corp', 'A', '${KEYCLOAK_INTERNAL_IP}', 86400, NULL);
EOF
