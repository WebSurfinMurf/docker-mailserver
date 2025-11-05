#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== Applying SMTP Relay Configuration ===${NC}"

# Source the environment file
source $HOME/projects/secrets/docker-mailserver.env

if [ -z "$RELAY_HOST" ] || [ -z "$RELAY_USER" ] || [ -z "$RELAY_PASSWORD" ]; then
    echo -e "${RED}Error: Relay configuration not found in docker-mailserver.env${NC}"
    exit 1
fi

echo -e "${YELLOW}Configuring relay settings...${NC}"
echo "Relay Host: $RELAY_HOST"
echo "Relay User: $RELAY_USER"

# Configure Postfix for relay
docker exec mailserver postconf -e "relayhost = $RELAY_HOST"
docker exec mailserver postconf -e "smtp_sasl_auth_enable = yes"
docker exec mailserver postconf -e "smtp_sasl_security_options = noanonymous"
docker exec mailserver postconf -e "smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd"
docker exec mailserver postconf -e "smtp_tls_security_level = encrypt"
docker exec mailserver postconf -e "smtp_tls_note_starttls_offer = yes"
docker exec mailserver postconf -e "header_size_limit = 4096000"

# Create SASL password file
echo -e "${YELLOW}Setting up authentication...${NC}"
docker exec mailserver sh -c "echo '$RELAY_HOST $RELAY_USER:$RELAY_PASSWORD' > /etc/postfix/sasl_passwd"
docker exec mailserver postmap hash:/etc/postfix/sasl_passwd
docker exec mailserver chmod 600 /etc/postfix/sasl_passwd
docker exec mailserver chmod 600 /etc/postfix/sasl_passwd.db

# Reload Postfix
echo -e "${YELLOW}Reloading mail server...${NC}"
docker exec mailserver postfix reload

echo -e "${GREEN}=== Relay Configuration Applied ===${NC}"
echo ""
echo -e "${GREEN}Your mail server is now using SendGrid relay${NC}"
echo "Emails will be sent through: smtp.sendgrid.net"
echo ""
echo -e "${YELLOW}Test it now:${NC}"
echo "1. Send an email from Nextcloud to your Gmail"
echo "2. It should deliver successfully!"
echo ""
echo -e "${YELLOW}Note: SendGrid limits:${NC}"
echo "- Free tier: 100 emails/day"
echo "- Check SendGrid dashboard for statistics"