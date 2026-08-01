# Gotchas

- **Traefik's TCP routing to mail is dead, not just unused.** `mailserver` used to get its
  Traefik TCP routers (25/465/587/993 TLS passthrough) via Docker labels. Since it moved to
  `network_mode: service:mail-edge-wg`, labels are forbidden on it (Docker rejects labels
  alongside `network_mode: service:*`), so those routers no longer exist. Confirmed:
  `openssl s_client -connect mail.ai-servicers.com:993` TLS-handshakes fine (cert is valid)
  but then gets `HTTP/1.1 400 Bad Request` instead of an IMAP banner — Traefik has no matching
  router and falls through to its HTTP stack. This silently broke Nextcloud Mail's existing
  IMAP/SMTP integration. Fix belongs in the `traefik` project (new label source, or a
  file-provider TCP route pointing at `mail-edge-wg`), not here.

- **A `mail-edge-wg` restart does not auto-recover `mailserver`.** Restarting `mail-edge-wg`
  destroys the shared network namespace; `mailserver` keeps running in the orphaned netns
  rather than getting restarted by Docker. `depends_on: condition: service_healthy` only
  orders startup, not runtime recovery. The `mailserver` healthcheck checks for a live `wg0`
  specifically to catch this, but you still have to restart `mailserver` by hand afterward.

- **PROXY protocol must be scoped per Postfix listener, not global.** Setting
  `postscreen_upstream_proxy_protocol`/`smtpd_upstream_proxy_protocol` in `postfix-main.cf`
  would also apply to the internal 127.0.0.1 amavis reinjection listener, which will never
  receive a PROXY header — breaking local delivery. Scope the directives in
  `postfix-master.cf` per listener instead.

- **`openssl s_client -verify N` only checks chain trust, not hostname match.** It will report
  `verify return:1` and complete the handshake against a cert whose SAN doesn't cover the name
  you connected as — `-servername` only sets SNI, it doesn't assert the match. This is exactly
  how `mailserver` served a cert with SAN `ai-servicers.com` only (missing
  `mail.ai-servicers.com`) for a while without any verification command catching it. Use
  `-verify_hostname <name>` to actually assert the match, and prove the flag is biting with a
  negative control (`-verify_hostname nope.example.com` should fail) before trusting a green
  result. Fixed 2026-07-28 — see `operations.md` TLS certificate source.

- **DKIM private key material lives under `config/opendkim/keys/`, owned by `root` inside the
  container** — unreadable by the host `administrator` user, and `.gitignore`d
  (`config/opendkim/`). Don't try to `git add` it; it'll fail with a permission error, and it
  should never be committed anyway.

- **`mta-sts.ai-servicers.com` already resolves (via the zone's `*.ai-servicers.com` wildcard
  CNAME → `home.ai-servicers.com`) but has no Traefik router — it 404s.** Don't mistake DNS
  resolution for HTTPS reachability. The MTA-STS policy file is authored at
  `mta-sts-policy/.well-known/mta-sts.txt` (mode: testing) but the `_mta-sts` TXT record is
  deliberately unpublished until a Traefik route exists to serve it — publishing the TXT record
  first would advertise a policy nothing can fetch (RFC 8461 §3 fail-closed behavior). See
  `docs/mail-dns-posture.md`.

- **CAA is a trap, not a free win.** Certificate Transparency shows a live
  `*.ai-servicers.com` cert issued by Google Trust Services (Cloudflare Universal SSL for the
  proxied apex) alongside the Let's Encrypt certs this project uses. A CAA record scoped to
  Let's Encrypt only would silently break that renewal (~60-day lead time) and Cloudflare can
  rotate its Universal SSL CA at any time. Do not add CAA without accounting for both issuers.
  See `docs/mail-dns-posture.md`.
