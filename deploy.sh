#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== Docker-Mailserver Deployment ===${NC}"

# Check if running as administrator
if [[ $EUID -eq 0 ]]; then
   echo -e "${RED}This script should not be run as root!${NC}"
   exit 1
fi

# Create necessary directories
echo -e "${YELLOW}Creating directories...${NC}"
mkdir -p data/{mail,state,postfixadmin} config

# Generate setup password for PostfixAdmin
if [ ! -f .postfixadmin_password ]; then
    echo -e "${YELLOW}Generating PostfixAdmin setup password...${NC}"
    SETUP_PASSWORD=$(openssl rand -base64 32)
    echo "POSTFIXADMIN_SETUP_PASSWORD=${SETUP_PASSWORD}" > .postfixadmin_password
    echo -e "${GREEN}Setup password saved to .postfixadmin_password${NC}"
fi

# Source the password
source .postfixadmin_password

# Export for docker-compose
export POSTFIXADMIN_SETUP_PASSWORD

# Create initial config files
echo -e "${YELLOW}Creating initial configuration...${NC}"

# Create postfix accounts file (empty initially)
touch config/postfix-accounts.cf
touch config/postfix-virtual.cf

# Deploy containers
echo -e "${YELLOW}Starting containers...${NC}"
docker compose up -d

# Wait for mailserver to be ready
echo -e "${YELLOW}Waiting for mailserver to be ready...${NC}"
sleep 10

# Show status
docker compose ps

echo -e "${GREEN}=== Deployment Complete ===${NC}"
echo ""
echo -e "${GREEN}Next Steps:${NC}"
echo "1. Access PostfixAdmin at: https://postfixadmin.ai-servicers.com/setup.php"
echo "2. Use setup password from .postfixadmin_password file"
echo "3. Create admin account and domains"
echo "4. Add mailboxes for your users"
echo ""
echo -e "${YELLOW}Mail Server Details:${NC}"
echo "SMTP: mail.ai-servicers.com:25 (incoming)"
echo "SUBMISSION: mail.ai-servicers.com:587 (outgoing)"
echo "IMAPS: mail.ai-servicers.com:993"
echo ""
echo -e "${YELLOW}DNS Records Needed:${NC}"
echo "MX: ai-servicers.com → mail.ai-servicers.com (priority 10)"
echo "A: mail.ai-servicers.com → YOUR_SERVER_IP"
echo "SPF: v=spf1 mx a ~all"
echo "DKIM: Will be generated after first run"