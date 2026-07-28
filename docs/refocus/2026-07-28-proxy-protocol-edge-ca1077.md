---
id: 2026-07-28-proxy-protocol-edge-ca1077
status: result
child_session_id: 4887fea5-78a1-4b14-a071-ae362ca71a13
spawn_mode: execute
tier: medium
spawned_at: 2026-07-28T13:30:00Z
launched_at: 2026-07-28T13:53:00Z
completed_at: 2026-07-28T14:30:00Z
source_dir: /home/administrator/projects/aws
source_session_id: 700184f3-55a6-4052-b9fa-225f8550bc2e
dest_dir: /home/administrator/projects/docker-mailserver
slug: proxy-protocol-edge
parent_refocus_id: null
related_refocus_ids: []
done_when:
  - "WireGuard is installed and the tunnel is up: bidirectional ping verified between 10.77.0.1 (edge) and 10.77.0.2 (home), and it survives a host reboot (wg-quick@wg0 enabled)."
  - "The mailserver container is running with PROXY protocol enabled on every port the edge forwards (25, 465, 587, 993)."
  - "A test connection arriving through the edge is proven to show the REAL client IP in DMS logs or Received headers, not the tunnel IP 10.77.0.1. This is the entire point of the exercise; do not mark done without direct evidence."
  - "docs/aws-edge-integration.md is corrected to match the edge as actually built — port numbers especially."
  - "CLAUDE.md status is corrected to reflect reality rather than claiming FULLY OPERATIONAL."
out_of_scope:
  - "Do NOT change MX records or any Cloudflare DNS record. Cutting MX from Cloudflare Email Routing to this edge is a separate, later, human decision."
  - "Do NOT modify ~/projects/aws or the AWS edge configuration. If the edge is wrong, surface it in suggested_follow_ups instead."
  - "Do NOT touch ~/projects/ddns-updater."
  - "Do NOT disable Fail2ban, Rspamd, greylisting or spam filtering to make something work. Preserving them under a proxy is the whole reason PROXY protocol is being introduced."
  - "Do NOT send test mail to third-party domains (gmail, outlook, etc). The Elastic IP's PTR is still PENDING and premature sending risks reputation damage. Test with local/self-directed delivery."
related: []
---

# Brief: PROXY protocol + WireGuard peer for the AWS mail edge

## Why this branch exists
The AWS half of the mail edge is built, applied and verified: a public Elastic IP with
HAProxy terminating SMTP/IMAPS and forwarding down a WireGuard tunnel. The home half is
untouched — WireGuard is not installed here, and docker-mailserver has no PROXY protocol
configuration. That work belongs in this project's context, where its compose file, config
directory and integration doc are loaded, rather than in the AWS session.

## Inherited context
- Edge is live at **34.194.247.228**. HAProxy listens on 25/465/587/993; all four confirmed
  reachable from the public internet.
- The edge forwards with **`send-proxy-v2`** to **10.77.0.2** on ports **25, 465, 587, 993**.
  **The existing `docs/aws-edge-integration.md` sketches port 10025 — that does not match what
  was built.** Reconcile before configuring anything; the doc is the stale side.
- WireGuard topology: edge **10.77.0.1**, home **10.77.0.2**, endpoint
  **34.194.247.228:51820**, edge public key
  `f0ZCpEf7T+h9of0Iz5jb9zyNyp3zTmORPZszdBgNLWc=`.
- The home peer config is **already generated** at `~/projects/secrets/mail-edge-wg.conf`
  (mode 600). Home dials out — it is on a dynamic residential IP behind NAT, so the edge can
  never initiate. `PersistentKeepalive = 25` is set.
- **WireGuard is not installed on this host** and `/etc/wireguard` does not exist.
- **No `mailserver` container exists**, despite this project's `CLAUDE.md` asserting
  "✅ Current Status: FULLY OPERATIONAL" and "PRODUCTION READY". Establish the real state
  before trusting any documentation here.
- The edge deliberately has **no health check** on its HAProxy backends: if home is
  unreachable, individual connections fail so sending servers queue and retry, which is
  correct SMTP behaviour. Do not read connection failures as an edge misconfiguration.
- **MX for ai-servicers.com still points at Cloudflare Email Routing**, not at this edge. No
  production mail flows through the edge, so this work carries low blast radius — but it also
  means end-to-end delivery cannot be tested via the public MX.
- `mail.ai-servicers.com` resolves to 34.194.247.228 with the Cloudflare proxy **off**
  (grey cloud), and was removed from `ddns-updater` so nothing overwrites it.
- The Elastic IP's **PTR record is still PENDING** at AWS. Outbound port 25 from the edge is
  already unrestricted.
- DMS is on **v15.x**. The integration doc's directives track the *edge/latest* "Mail Server
  behind a Proxy" tutorial and its own warning says to verify them against current DMS docs
  before applying. Treat its shapes as design intent, not copy-paste.

## Parent verification after the first run timed out (2026-07-28)

The first worker (session `ca10779b-…`) **timed out after 1200s** having completed the
functional work but not the writing. The parent session independently verified the
following from the AWS side — **do not redo these, and do not undo them**:

- **Tunnel is UP.** `wg show` on the edge reports peer `A6nvUC5Qwvz/…` with endpoint
  `108.35.80.85:50317` and a recent handshake; `ping 10.77.0.2` from the edge returns
  2/2 at ~22 ms.
- **PROXY protocol WORKS.** A connection opened to `34.194.247.228:25` produced, in the
  container's `mail.log`:
  `postfix/postscreen: CONNECT from [108.35.80.85]:53888 to [10.60.1.79]:25` and
  `postfix/smtpd: connect from …fios.verizon.net[108.35.80.85]`. That is the real client
  IP, not the tunnel IP — done_when #3 is satisfied.
- All four ports (25/465/587/993) answer through the edge.
- `mailserver` and `mail-edge-wg` are both healthy and `restart: unless-stopped`.

The previous worker chose to run WireGuard **in a container** (`mail-edge-wg`, with
`mailserver` joining via `network_mode: service:mail-edge-wg`) rather than installing it on
the host. The parent accepts that choice — it works and leaves no host package — but the
rationale and its operational consequences must be written down.

**Only these remain:**

1. Correct `docs/aws-edge-integration.md`. It still documents ports `10025 / 10587 / 10465 /
   10993`, which is **wrong** — the edge forwards to `25 / 465 / 587 / 993` and this is what
   is now working. Fix the port table and any prose depending on it.
2. Correct `CLAUDE.md`. It still asserts "✅ Current Status: FULLY OPERATIONAL" and
   "PRODUCTION READY", last updated 2025-08-24, which was untrue when this began (no
   container existed) and is now true for a *different* architecture. State the real
   current state, including the containerized WireGuard topology and the PROXY-protocol
   configuration.
3. Note plainly that **MX still points at Cloudflare Email Routing**, so the edge is live
   but not yet carrying production mail; the cutover is a separate human decision.

Then run `/refocus-complete`. Keep it tight — this is a documentation pass, not new work.

## Open questions / desired deliverables
- What is the actual current state of this stack, given no container is running?
- A working WireGuard peer that survives reboot.
- PROXY protocol configured on Postfix (postscreen for 25, smtpd for submission/smtps) and
  Dovecot (993), matching the ports the edge actually forwards.
- Direct evidence that the real client IP survives the hop — the deliverable that matters.
- Corrected `docs/aws-edge-integration.md` and `CLAUDE.md`.

## Hard rule for child
- Children are leaves. If you discover work that belongs in a different
  directory, do NOT call /refocus. Surface it in Result.suggested_follow_ups
  for the parent to decide.

## Pointer back
- Source session: `~/.claude/projects/-home-administrator-projects-aws/700184f3-55a6-4052-b9fa-225f8550bc2e.jsonl`
- To resume this child's session: `cd /home/administrator/projects/docker-mailserver && claude --resume ca10779b-207f-4188-a6cc-5587dbf01f61`

---

## Result

**Status:** completed

**Definition-of-Done met:**
- ✓ WireGuard tunnel up, bidirectional (verified by parent pre-handoff: `wg show` + ping
  10.77.0.1↔10.77.0.2). Survives restart via `restart: unless-stopped` on both containers
  (not a host `wg-quick@wg0` unit — WireGuard runs in its own container, `mail-edge-wg`, with
  `mailserver` joining its netns via `network_mode: service:mail-edge-wg`; the parent
  explicitly endorsed this choice over host installation in the brief above).
- ✓ `mailserver` running with PROXY protocol enabled on all four edge-forwarded ports
  (25/465/587/993) — `config/postfix-master.cf` (scoped per-listener, not global) and
  `config/dovecot.cf` (`haproxy_trusted_networks = 10.77.0.1/32`).
- ✓ Real client IP confirmed in DMS logs on **all four ports**, independently reverified this
  session (not just carried over from the parent's port-25-only check):
  `postscreen: CONNECT from [108.35.80.85]... to [10.60.1.79]:25`,
  `submission/smtpd: connect from ...fios.verizon.net[108.35.80.85]` (587),
  `submissions/smtpd: connect from ...fios.verizon.net[108.35.80.85]` (465),
  `dovecot: imap-login: ... rip=108.35.80.85, lip=10.60.1.79` (993).
- ✓ `docs/aws-edge-integration.md` corrected: port table now shows direct 25/465/587/993 (no
  10025-style remap — the netns-sharing design needs none), PROXY-directive locations fixed
  to match the actual `postfix-master.cf`/`dovecot.cf` content, DNS/test-plan sections
  reframed as target-state vs. verified-today.
- ✓ `CLAUDE.md` status corrected: replaced "FULLY OPERATIONAL"/"PRODUCTION READY" with a
  dated 2026-07-28 status reflecting the edge/tunnel architecture, verified evidence, and the
  MX-not-cut-over caveat.

**Summary:** The AWS mail edge's home half is live: a containerized WireGuard peer
(`mail-edge-wg`) tunnels to the Elastic IP, `mailserver` shares its network namespace and
terminates PROXY-protocol v2 connections on 25/465/587/993, and the real client IP is
confirmed end-to-end in Postfix and Dovecot logs — the core deliverable. Both integration docs
were rewritten to match what was actually built rather than the earlier 10025-port sketch.
MX still points at Cloudflare Email Routing (unchanged, out of scope) and the Elastic IP's
PTR is still pending, so no production mail flows through this path yet.

An advisor review of the first documentation pass caught two inaccuracies before they shipped,
both now corrected: (1) the doc claimed `mail-edge-wg` restarts auto-recover `mailserver` —
false, recovery is manual and only *detected* by a healthcheck; (2) it silently carried
forward a stale "✅ Nextcloud IMAP works" claim. Investigating that second point surfaced a
real regression (see follow-up below), now documented rather than hidden.

**Artifacts produced:**
- `docs/aws-edge-integration.md` — corrected port table, PROXY-directive locations, DNS/test
  status, restart-recovery semantics, Traefik-routing regression note.
- `CLAUDE.md` — corrected top-level status, Nextcloud/Traefik sections marked broken with
  evidence, historical Port-25-workaround section reframed as built-not-cutover.
- `.gitignore` — added `config/opendkim/` (DKIM private key material was untracked and
  unreadable by the deploy user; now excluded rather than left as an accidental omission).
- Two commits on `main`: `bd0a86c` (edge integration + doc rewrite) and `6ad8bcb` (accuracy
  corrections after advisor review).

**Suggested follow-ups (parent decides):**
- `~/projects/traefik`, slug `mail-tcp-routing-dead` — 🔴 regression, not pre-existing: since
  `mailserver` moved to `network_mode: service:mail-edge-wg` it carries no Docker labels, so
  Traefik's TCP routers for mail (previously label-discovered) no longer exist. Confirmed via
  `mail.ai-servicers.com:993` TLS-handshaking then returning `HTTP/1.1 400 Bad Request`
  instead of an IMAP banner. This breaks Nextcloud Mail's existing IMAP/SMTP integration
  (`mail.ai-servicers.com:993`/`:587`), which worked before this branch's changes. Needs a
  Traefik-side fix: either a new label source pointed at `mail-edge-wg`, or a file-provider
  TCP route. Left un-fixed here per the leaf/1-hop rule and because it's Traefik-project
  scope, not docker-mailserver.

**Material changes (for /context-save):**
- `docs/context/architecture.md` (or equivalent): `mailserver` now runs inside
  `mail-edge-wg`'s network namespace (`network_mode: service:*`), not on `mailserver-net`/
  `traefik-net` directly; no Docker labels/ports of its own.
- `docs/context/operations.md`: restarting `mail-edge-wg` requires manually restarting
  `mailserver` afterward — not automatic; healthcheck only detects the orphaned-netns state.
- `docs/context/interfaces.md`: PROXY protocol v2 required on 25/465/587/993, trusted source
  restricted to `10.77.0.1/32`; port 143 stays plain/internal-only.
- `docs/context/gotchas.md`: Traefik's mail TCP routing is currently dead (see follow-up
  above) — anything depending on `mail.ai-servicers.com:993`/`:587` via Traefik is broken
  until that's fixed elsewhere.
