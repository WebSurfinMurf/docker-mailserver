# Architecture

## Components
- `mailserver` — `ghcr.io/docker-mailserver/docker-mailserver:latest`. [IMPLEMENTED] Runs with
  `network_mode: service:mail-edge-wg` — no `networks:`, `ports:`, or Docker labels of its own.
  It shares the network namespace of `mail-edge-wg` instead of attaching directly to
  `mailserver-net`/`traefik-net`.
- `mail-edge-wg` — `lscr.io/linuxserver/wireguard`. [IMPLEMENTED] Containerized WireGuard peer
  that owns the shared netns. Dials out to the AWS mail edge (Elastic IP `34.194.247.228`,
  endpoint `:51820`); home never receives inbound WireGuard connections (dynamic residential
  IP behind NAT). Tunnel addresses: edge `10.77.0.1`, home `10.77.0.2`.
- `postfixadmin` — profile-gated (`profiles: ["postfixadmin"]`), on `mailserver-net` +
  `traefik-net` directly (not affected by the netns change); reaches mail via
  `mail-edge-wg:25` since that's the only DNS name in the shared netns.

## Data flow (mail edge path)
1. External client → `34.194.247.228:{25,465,587,993}` (AWS HAProxy).
2. HAProxy prepends a PROXY protocol v2 header with the real client IP, forwards over
   WireGuard to `10.77.0.2:{25,465,587,993}`.
3. Postfix (`postscreen` on 25, `smtpd` on 587/465) and Dovecot (`imap-login` on 993) read the
   PROXY header and log/score/authenticate against the real client IP, not the tunnel peer.

## Known gap
- [BROKEN] Traefik's TCP routing to mail (previously Docker-label-discovered on `mailserver`)
  has no backend now that those labels don't exist. See `gotchas.md`.

## See also
- `docs/aws-edge-integration.md` — full edge design + verified evidence.
- `docs/refocus/2026-07-28-proxy-protocol-edge-ca1077.md` — the session that built this.
- `docs/mail-dns-posture.md` — canonical SPF/DKIM/DMARC/MTA-STS/TLS-RPT record for
  `ai-servicers.com`, including why DMARC stays at `p=none` and why CAA/DNSSEC are absent.
