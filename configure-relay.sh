#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== Configure SMTP Relay for Docker-Mailserver ===${NC}"
echo ""
echo -e "${YELLOW}This configures your mail server to use an SMTP relay service${NC}"
echo -e "${YELLOW}This is required to send mail to Gmail, Outlook, etc.${NC}"
echo ""

# Get relay choice
echo "Select SMTP Relay Service:"
echo "1) SendGrid (recommended - 100 emails/day free)"
echo "2) Amazon SES"
echo "3) Mailgun"
echo "4) Custom SMTP relay"
read -p "Enter choice (1-4): " choice

case $choice in
    1)
        RELAY_HOST="[smtp.sendgrid.net]:587"
        echo -e "${YELLOW}Sign up at https://sendgrid.com${NC}"
        echo "Create an API Key at: Settings -> API Keys"
        read -p "Enter SendGrid username (usually 'apikey'): " RELAY_USER
        read -s -p "Enter SendGrid API Key: " RELAY_PASSWORD
        echo
        ;;
    2)
        read -p "Enter SES SMTP endpoint (e.g., email-smtp.us-east-1.amazonaws.com): " SES_HOST
        RELAY_HOST="[$SES_HOST]:587"
        read -p "Enter SES SMTP username: " RELAY_USER
        read -s -p "Enter SES SMTP password: " RELAY_PASSWORD
        echo
        ;;
    3)
        RELAY_HOST="[smtp.mailgun.org]:587"
        read -p "Enter Mailgun SMTP username: " RELAY_USER
        read -s -p "Enter Mailgun SMTP password: " RELAY_PASSWORD
        echo
        ;;
    4)
        read -p "Enter relay host (e.g., smtp.example.com): " CUSTOM_HOST
        read -p "Enter relay port (usually 587): " CUSTOM_PORT
        RELAY_HOST="[$CUSTOM_HOST]:$CUSTOM_PORT"
        read -p "Enter relay username: " RELAY_USER
        read -s -p "Enter relay password: " RELAY_PASSWORD
        echo
        ;;
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

# Configure relay in Docker-Mailserver
echo -e "${YELLOW}Configuring relay settings...${NC}"

# Add relay configuration
docker exec mailserver postconf -e "relayhost = $RELAY_HOST"
docker exec mailserver postconf -e "smtp_sasl_auth_enable = yes"
docker exec mailserver postconf -e "smtp_sasl_security_options = noanonymous"
docker exec mailserver postconf -e "smtp_sasl_password_maps = lmdb:/etc/postfix/sasl_passwd"
docker exec mailserver postconf -e "smtp_tls_security_level = encrypt"
docker exec mailserver postconf -e "header_size_limit = 4096000"

# Create SASL password file
echo -e "${YELLOW}Setting up authentication...${NC}"
docker exec mailserver sh -c "echo '$RELAY_HOST $RELAY_USER:$RELAY_PASSWORD' > /etc/postfix/sasl_passwd"
docker exec mailserver postmap /etc/postfix/sasl_passwd
docker exec mailserver chmod 600 /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.lmdb

# Reload Postfix
echo -e "${YELLOW}Reloading mail server...${NC}"
docker exec mailserver postfix reload

# Test configuration
echo -e "${GREEN}=== Relay Configuration Complete ===${NC}"
echo ""
echo -e "${GREEN}Your mail server is now configured to relay through:${NC}"
echo "Relay Host: $RELAY_HOST"
echo ""
echo -e "${YELLOW}Testing: Send a test email to your Gmail to verify${NC}"
echo ""
echo -e "${YELLOW}Note: Some relay services require:${NC}"
echo "- Domain verification"
echo "- Sender authentication"
echo "- IP whitelisting"
echo ""
echo -e "${GREEN}Check your relay service dashboard for any additional setup${NC}"