# Interfaces

## Mail ports — PROXY protocol contract (edge-forwarded)
| Port | Service | Listener | PROXY required | Trusted source |
|---|---|---|---|---|
| 25 | SMTP | Postfix `postscreen` | yes (`postscreen_upstream_proxy_protocol=haproxy`) | edge sends `send-proxy-v2` |
| 587 | Submission | Postfix `smtpd` (`submission/inet`) | yes | edge sends `send-proxy-v2` |
| 465 | SMTPS | Postfix `smtpd` (`submissions/inet`, DMS's name for it — not `smtps`) | yes | edge sends `send-proxy-v2` |
| 993 | IMAPS | Dovecot `imap-login` (`imaps` listener) | yes (`haproxy = yes`) | `haproxy_trusted_networks = 10.77.0.1/32` |
| 143 | IMAP | Dovecot `imap-login` (`imap` listener) | no | not exposed outside `mail-edge-wg`'s netns |

A listener with PROXY enabled **requires** the header on every connection — it cannot also
serve plain TCP. This is why direct (non-tunnel) access to these ports no longer works; see
`gotchas.md`.

## Config file → directive map
- `config/postfix-master.cf` — per-listener PROXY overrides (25/587/465). Deliberately NOT in
  `postfix-main.cf`, which would also apply to the internal 127.0.0.1 amavis reinjection
  listener and break local delivery.
- `config/dovecot.cf` — `haproxy_trusted_networks`, `haproxy_timeout`, and the `imaps`
  listener's `haproxy = yes` override.

## WireGuard tunnel
- Edge: `10.77.0.1`, endpoint `34.194.247.228:51820`.
- Home: `10.77.0.2`, config at `~/projects/secrets/mail-edge-wg.conf`, `AllowedIPs =
  10.77.0.0/24`, `PersistentKeepalive = 25`.
