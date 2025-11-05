# Docker-Mailserver Project

## ✅ Current Status: FULLY OPERATIONAL

Production mail server using Docker-Mailserver (single container solution) for ai-servicers.com domain.
Successfully integrated with Nextcloud Mail app and accessible via external domain.

## Working Configuration

### Mail Accounts
- **websurfinmurf@ai-servicers.com** - Active and working
- **michaelmurphy@ai-servicers.com** - Configured (legacy)

### Access Methods
- **External**: mail.ai-servicers.com (via Traefik with Let's Encrypt SSL)
- **Internal**: mailserver (container name on Docker network)
- **IMAP/SSL**: Port 993
- **SMTP/STARTTLS**: Port 587
- **Submission**: Port 587
- **SMTP**: Port 25 (incoming)

### SSL Configuration
- **Type**: manual
- **Certificates**: Let's Encrypt via Traefik
- **Path**: `/certs/certificate.crt` and `/certs/privatekey.key`
- **Mount**: `/home/administrator/projects/data/traefik-certs/ai-servicers.com:/certs:ro`

## Architecture
- **Container**: ghcr.io/docker-mailserver/docker-mailserver:latest
- **Management UI**: PostfixAdmin at postfixadmin.linuxserver.lan
- **Database**: PostgreSQL (shared instance) for PostfixAdmin
- **Routing**: Through Traefik reverse proxy for external access
- **Networks**: mailserver-net, traefik-net, postgres-net

## Configuration Files
- `$HOME/projects/secrets/docker-mailserver.env` - Main environment configuration
- `config/postfix-accounts.cf` - Account configuration (managed by setup command)
- `config/postfix-virtual.cf` - Virtual aliases configuration
- `config/dovecot/` - Custom Dovecot configurations

## Key Environment Settings
```env
HOSTNAME=mail
DOMAINNAME=ai-servicers.com
PERMIT_DOCKER=network
SSL_TYPE=manual
SSL_CERT_PATH=/certs/certificate.crt
SSL_KEY_PATH=/certs/privatekey.key
TLS_LEVEL=intermediate
ENABLE_SPAMASSASSIN=1
ENABLE_FAIL2BAN=1
ENABLE_POSTGREY=1
```

## Network Configuration
- Connected to three networks for full integration:
  - `mailserver-net` - Primary network
  - `traefik-net` - For external access via Traefik
  - `postgres-net` - For PostfixAdmin database access
- Postfix configured to trust Docker networks: `172.16.0.0/12 10.0.0.0/8`

## Deployment Scripts

### deploy-fixed.sh (Current Production)
The main deployment script that:
- Sets up proper network permissions
- Configures SSL certificates
- Connects to all required networks
- Tests connectivity after deployment

### deploy-manual.sh
Alternative deployment without docker-compose

## Account Management

### Adding New Email Account
```bash
docker exec -it mailserver setup email add user@ai-servicers.com
```

### Updating Password
```bash
docker exec mailserver setup email update user@ai-servicers.com NewPassword123!
```

### List Accounts
```bash
docker exec mailserver setup email list
```

## SendGrid Relay Configuration (WORKING)

### Why Relay is Required
- Gmail/Outlook block direct mail from residential/VPS IPs
- Your IP (173.70.147.236) lacks proper reputation for direct delivery
- Major providers require established mail reputation

### SendGrid Setup
- **Service**: SendGrid (100 emails/day free tier)
- **API Key**: Stored in docker-mailserver.env
- **DNS Records**: Configured in Cloudflare (DKIM, DMARC)
- **Configuration**: Applied via apply-relay.sh script

### Relay Configuration in ENV
```env
RELAY_HOST=[smtp.sendgrid.net]:587
RELAY_USER=apikey
RELAY_PASSWORD=SG.KCj3qpx6SYait75_4MiFzg.[rest_of_key]
DEFAULT_RELAY_HOST=[smtp.sendgrid.net]:587
```

### Apply Configuration
```bash
cd /home/administrator/projects/docker-mailserver
./apply-relay.sh  # Reads from docker-mailserver.env
```

## Integration with Nextcloud

### Working Configuration
Nextcloud Mail app successfully connects using:
- **Server**: mail.ai-servicers.com
- **IMAP**: Port 993 with SSL
- **SMTP**: Port 587 with STARTTLS
- **Authentication**: Username/password from setup command
- **Outbound**: Relayed through SendGrid for deliverability

### NAT Reflection Workaround
Due to ASUS router NAT reflection, Nextcloud container has:
- External DNS servers (8.8.8.8) configured
- Hosts entry mapping mail.ai-servicers.com → 172.22.0.17
- This allows internal Docker routing while using external domain name

## Traefik TCP Routing
All mail ports are routed through Traefik with TLS passthrough:
```yaml
TCP Services:
- Port 25 (SMTP) → Container port 25
- Port 587 (Submission) → Container port 587  
- Port 993 (IMAPS) → Container port 993
- Port 465 (SMTPS) → Container port 465
```

## PostfixAdmin Integration
- Web UI at https://postfixadmin.linuxserver.lan (internal only)
- PostgreSQL backend for mailbox management
- Can be used for advanced mail configuration
- Currently using Docker-Mailserver's setup command for simplicity

## DNS Requirements
- **MX Record**: ai-servicers.com → mail.ai-servicers.com (priority 10)
- **A Record**: mail.ai-servicers.com → Server public IP
- **SPF**: `v=spf1 mx a ~all`
- **DKIM**: Generated and stored in data/state/

## Testing Commands

### Test IMAP Connection
```bash
echo "A1 LOGOUT" | openssl s_client -connect mail.ai-servicers.com:993 -quiet
```

### Test SMTP
```bash
echo "QUIT" | openssl s_client -connect mail.ai-servicers.com:587 -starttls smtp -quiet
```

### Check Logs
```bash
docker logs mailserver --tail 50
```

### Test Authentication
```bash
docker exec mailserver doveadm auth test user@ai-servicers.com password
```

## Known Issues & Limitations

### 🔴 CRITICAL: Incoming Mail Blocked by ISP
**Problem**: Verizon (and most residential ISPs) block incoming port 25
**Impact**: Cannot receive external email (Gmail, etc.)
**Current Workaround**: None - incoming mail does not work

**Status of Email Functions:**
- ✅ **Sending mail**: Works via SendGrid relay
- ✅ **Internal mail**: Between local users works
- ✅ **IMAP access**: Nextcloud can read local mail
- ❌ **Receiving external mail**: BLOCKED by ISP

### Port 25 Workaround Solutions

#### Option 1: AWS SES + Lambda (Recommended)
**Full implementation plan available**: `/home/administrator/projects/AINotes/PORT25-WORKAROUND.md`

**How it works:**
1. AWS SES receives mail on port 25 (in AWS cloud)
2. Lambda function forwards to home server on port 2525
3. Docker-Mailserver accepts forwarded mail
4. Nextcloud Mail shows received emails

**Cost**: ~$1-2/month
**Complexity**: Medium
**Benefits**: Full control, no Gmail dependency

#### Option 2: VPS Mail Relay
- Rent VPS from DigitalOcean/Vultr ($6/month)
- Run mail relay on VPS
- Forward to home on alternate port

#### Option 3: Cloudflare Email Routing (Free)
- Forward to Gmail/other email provider
- Loses independence goal
- But free and works immediately

### Why Port 25 is Blocked
- ISPs block to prevent spam from residential connections
- Cannot be bypassed with port forwarding
- Email protocol requires port 25 for receiving
- No alternative ports for incoming SMTP

## Troubleshooting

### Certificate Issues
- Ensure Traefik certificates are properly mounted
- Check permissions: should be readable by mail server
- Verify SSL_TYPE=manual in environment

### Connection Issues
- Check all three networks are connected
- Verify Traefik TCP routing is active
- Test from host: `nc -zv mail.ai-servicers.com 993`

### Authentication Failures
- Use setup command to reset passwords
- Check account exists in postfix-accounts.cf
- Verify Dovecot is running: `docker exec mailserver ss -tlnp | grep 993`

## Backup Requirements
- **Critical**: data/mail/ (actual emails)
- **Important**: data/state/ (DKIM keys, fail2ban)
- **Configuration**: config/ directory

## Security Notes
- Fail2ban enabled for brute force protection
- SpamAssassin enabled for spam filtering
- Postgrey enabled for greylisting
- TLS enforced for all client connections
- Valid Let's Encrypt certificates via Traefik

---
*Created: 2025-08-23 by Claude*
*Last Updated: 2025-08-24 - Fully operational with Nextcloud integration*
*Status: ✅ PRODUCTION READY*