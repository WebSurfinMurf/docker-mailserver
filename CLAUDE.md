# Docker-Mailserver Project

> 🔀 **Session history (refocus)**: See [docs/refocus/INDEX.md](docs/refocus/INDEX.md) for incoming briefs and outbound spawns.

## Current Status (2026-07-28): AWS edge live, MX not yet cut over

The stack was rebuilt behind an AWS edge (`~/projects/aws/mail-edge/`, Elastic IP
`34.194.247.228`) because Verizon residential blocks inbound port 25 and lacks IP reputation
for outbound delivery. See [`docs/aws-edge-integration.md`](docs/aws-edge-integration.md) for
the full design, verified log evidence, and open items — this section is the summary.

- `mailserver` and `mail-edge-wg` (containerized WireGuard peer) are both **up and healthy**.
  `mailserver` joins `mail-edge-wg`'s network namespace via `network_mode:
  service:mail-edge-wg` — it has no `networks:`/`ports:`/Traefik labels of its own; restarting
  `mail-edge-wg` destroys that namespace and requires restarting `mailserver` afterward.
- PROXY protocol (HAProxy v2) is configured on Postfix (`config/postfix-master.cf`, scoped
  per-listener) and Dovecot (`config/dovecot.cf`, `haproxy_trusted_networks = 10.77.0.1/32`)
  for all four edge-forwarded ports: 25, 465, 587, 993. **Verified working** — DMS logs show
  the real client IP end-to-end, not the tunnel peer's.
- **MX for `ai-servicers.com` still points at Cloudflare Email Routing.** No production mail
  flows through this edge yet; cutover is a deliberate, separate human decision (not
  automated). `mail.ai-servicers.com` currently resolves to the Elastic IP with Cloudflare's
  proxy off, and was removed from `ddns-updater` so nothing overwrites it.
- The Elastic IP's PTR record is still **pending** at AWS — do not send test mail to
  third-party domains (Gmail, Outlook, etc.) until it resolves.
- 🔴 **Regression: Traefik's TCP routing to mail is currently broken**, and with it internal
  clients that relied on it (e.g. Nextcloud Mail at `mail.ai-servicers.com:993`/`:587`).
  Traefik discovered mail routers from Docker labels on the old `mailserver` container;
  `network_mode: service:*` forbids labels on the new one, so those routers no longer exist.
  Confirmed: `mail.ai-servicers.com:993` now TLS-handshakes then returns
  `HTTP/1.1 400 Bad Request` instead of proxying IMAP. See "Traefik TCP Routing" below and
  `docs/aws-edge-integration.md` for detail. Fixing this is a Traefik-project change, not done
  here.

### Mail Accounts
- **websurfinmurf@ai-servicers.com** - Active and working
- **michaelmurphy@ai-servicers.com** - Configured (legacy)

### SSL Configuration
- **Type**: manual
- **Certificates**: Let's Encrypt via Traefik (`traefik-certs-dumper`, `file --domain-subdir`
  mode — writes one directory per certificate under
  `/home/administrator/projects/data/traefik-certs/`)
- **Path**: `/certs/certificate.crt` and `/certs/privatekey.key`
- **Mount**: `"/home/administrator/projects/data/traefik-certs/*.ai-servicers.com:/certs:ro"`
  — the **wildcard** cert dir, not the apex-only `ai-servicers.com` dir. Fixed 2026-07-28:
  `mailserver`'s `OVERRIDE_HOSTNAME` is `mail.ai-servicers.com`, and clients that verify the
  peer (Nextcloud Mail) need `mail.ai-servicers.com` in the SAN. The apex-only dir's cert has
  SAN `ai-servicers.com` only and fails that verification; the wildcard dir's cert has SAN
  `*.ai-servicers.com, ai-servicers.com` and covers it. Traefik's cert extraction was never
  broken — it always wrote both dirs — `docker-compose.yml` was just pointed at the wrong one.
  Two gotchas: the directory name is literally `*.ai-servicers.com` (a glob character in a
  path — not a shell glob, Compose passes bind-mount sources through literally, but quote the
  YAML string anyway since a plain scalar *starting* with `*` would otherwise be parsed as a
  YAML alias); and this directory lives under `projects/data/traefik-certs/`, which is
  hard-denied for writes by the destructive-guard hook — inspect it read-only via
  `docker exec` into a container that already mounts it (e.g. `traefik-certs-dumper`), never
  edit it directly.

## Architecture
- **Container**: ghcr.io/docker-mailserver/docker-mailserver:latest, joined to
  `mail-edge-wg`'s netns (see Current Status above) — no direct `mailserver-net`/`traefik-net`
  attachment of its own.
- **WireGuard peer**: `mail-edge-wg` (`lscr.io/linuxserver/wireguard`), dials out to the AWS
  edge at `34.194.247.228:51820`; tunnel addresses `10.77.0.1` (edge) / `10.77.0.2` (home).
- **Management UI**: PostfixAdmin at postfixadmin.ai-servicers.com
- **Database**: PostgreSQL (shared instance) for PostfixAdmin
- **Networks**: `mailserver-net` (mail-edge-wg, postfixadmin), `traefik-net` (postfixadmin only)

## Configuration Files
- `$HOME/projects/secrets/docker-mailserver.env` - Main environment configuration
- `$HOME/projects/secrets/mail-edge-wg.conf` - WireGuard peer config (mode 600)
- `config/postfix-accounts.cf` - Account configuration (managed by setup command)
- `config/postfix-virtual.cf` - Virtual aliases configuration
- `config/postfix-master.cf` - PROXY protocol overrides (Postfix side)
- `config/dovecot.cf` - PROXY protocol overrides (Dovecot side)

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

### 🔴 Currently broken (2026-07-28) — see Current Status above
Nextcloud Mail previously connected via `mail.ai-servicers.com:993`/`:587` through Traefik's
TCP passthrough. That path is confirmed dead now that `mailserver` carries no Docker labels
(`network_mode: service:*` forbids them) — Traefik has no router to send it to. This section
describes the *previously working* configuration, kept for reference; it is not currently
functional and needs a Traefik-side fix (new label source, or a file-provider route to
`mail-edge-wg`) that is out of scope for the edge/tunnel work described above.

**Update 2026-07-28**: a *second*, independent blocker was diagnosed and fixed here — the
certificate `mailserver` presented had SAN `ai-servicers.com` only (wrong bind-mount source
dir; see SSL Configuration above), so peer-verifying clients rejected `mail.ai-servicers.com`
regardless of which network path reached it. That's now fixed and verified (peer-verified TLS
against `34.194.247.228:993` with SNI `mail.ai-servicers.com` succeeds). The Traefik LAN
routing regression described in this section is unrelated and still open — but per the parent
brief's inherited context, Nextcloud's container resolver returns the AWS Elastic IP for
`mail.ai-servicers.com` (external DNS), not the LAN address, so it may not actually route
through Traefik at all. Confirming that and any remaining Nextcloud-side config is out of
scope for this project — belongs to the `projects/nextcloud` session.

Nextcloud Mail app previously connected using:
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

## Traefik TCP Routing — 🔴 broken, not currently in effect
Previously all mail ports were routed through Traefik with TLS passthrough via Docker labels
on the `mailserver` container:
```yaml
TCP Services (as previously configured, no longer discovered):
- Port 25 (SMTP) → Container port 25
- Port 587 (Submission) → Container port 587
- Port 993 (IMAPS) → Container port 993
- Port 465 (SMTPS) → Container port 465
```
`mailserver` no longer has these labels (or any `networks:`/`ports:`) since it moved to
`network_mode: service:mail-edge-wg` for the AWS edge integration. Traefik still listens on
these host ports but has no matching router — confirmed via
`openssl s_client -connect mail.ai-servicers.com:993`, which TLS-handshakes then gets
`HTTP/1.1 400 Bad Request` instead of an IMAP banner.

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

### 🟡 Port 25 ISP block — workaround BUILT, not yet cut over
**Problem**: Verizon (and most residential ISPs) block incoming port 25.
**Solution built**: an AWS edge (Elastic IP + HAProxy, `~/projects/aws/mail-edge/`) tunnelled
home over WireGuard with PROXY protocol preserving the real client IP — see
[`docs/aws-edge-integration.md`](docs/aws-edge-integration.md). This superseded the older
AWS-SES+Lambda and VPS-relay options once considered (both listed below for history; neither
was built).
**Why it isn't live yet**: MX still points at Cloudflare Email Routing, and the Elastic IP's
PTR record is still pending at AWS. Cutover is a deliberate human decision, not automated.

**Status of Email Functions:**
- ✅ **Sending mail**: SendGrid relay connectivity reverified 2026-07-28 (TLS handshake ok
  from inside `mailserver`); path unaffected since WireGuard `AllowedIPs` is scoped to
  `10.77.0.0/24`, not general egress
- ✅ **Internal mail**: Between local users works
- 🔴 **IMAP access via Nextcloud**: BROKEN as of 2026-07-28 — see "Currently broken" note in
  Integration with Nextcloud, below. Was working before the edge refactor removed Traefik's
  route to `mailserver`.
- ✅ **Edge tunnel + PROXY protocol**: built and verified (real client IP confirmed in logs)
- ⬜ **Receiving external mail via the edge**: mechanism works end-to-end technically, but
  MX cutover hasn't happened — no production mail flows through it yet

### Historical options considered (not built)
- **AWS SES + Lambda**: SES receives on 25 in-cloud, Lambda forwards to home on 2525. Not
  chosen — the WireGuard+HAProxy edge gives more control over PROXY protocol/IP preservation.
- **VPS mail relay** (DigitalOcean/Vultr, ~$6/mo): superseded by the AWS edge.
- **Cloudflare Email Routing** (free, forward-only): still what MX points at today — it's the
  current fallback, not a rejected option.

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