# Mail DNS Posture — ai-servicers.com

Canonical record of the DNS-level mail security controls for `ai-servicers.com`. Verified live
against Cloudflare (authoritative) and 1.1.1.1/8.8.8.8 (public resolvers) on 2026-08-01. The
zone has 16 records total — small enough to enumerate directly via the Cloudflare API rather
than trust any cached summary.

## Current state (verified 2026-08-01)

| Control | Status | Value |
|---|---|---|
| MX | ✅ live | `10 mail.ai-servicers.com` → `34.194.247.228` (AWS mail edge) |
| SPF | ✅ live | `v=spf1 a:mail.ai-servicers.com include:sendinblue.com ~all` |
| DKIM | ✅ live | selectors `mail` (home server), `s1`/`s2` (SendGrid), `brevo1`/`brevo2` (Brevo) |
| DMARC | ✅ live, **not enforcing** | `v=DMARC1; p=none; rua=mailto:rua@dmarc.brevo.com` |
| TLS-RPT | ✅ **published this session** | `_smtp._tls.ai-servicers.com` → `v=TLSRPTv1; rua=mailto:tlsrpt@ai-servicers.com` |
| MTA-STS | ⬜ **authored, not published** | policy file ready at `mta-sts-policy/.well-known/mta-sts.txt`; `_mta-sts` TXT record intentionally withheld — see below |
| CAA | ⬜ absent — **intentionally**, do not add | see "Why CAA is a trap" below |
| DNSSEC | ⬜ absent — **intentionally**, do not enable | out of scope, no owner decision made |

## Three authorized senders (why DMARC stays at `p=none`)

`ai-servicers.com` mail is legitimately sent from three independent sources, each with its own
DKIM selector:

1. **Home server** (this project) — selector `mail`, sends via the AWS mail edge
   (`mail.ai-servicers.com`, `34.194.247.228`).
2. **SendGrid** — selectors `s1`/`s2._domainkey`, plus `em903.ai-servicers.com` CNAME. Used as
   the outbound relay for deliverability (see project `CLAUDE.md` — SendGrid Relay
   Configuration).
3. **Brevo** (formerly Sendinblue) — selectors `brevo1`/`brevo2._domainkey`, and referenced
   directly in the SPF record (`include:sendinblue.com`) and the DMARC `rua` target
   (`dmarc.brevo.com`).

DMARC alignment across all three has not been confirmed. Moving off `p=none` before that
confirmation risks silently dropping legitimate mail from SendGrid or Brevo. **This is an
explicit owner decision, not made in this session** — see `out_of_scope` in
`docs/refocus/2026-08-01-mail-tls-reporting-c12924.md`.

A secondary issue, noted but also out of scope: the DMARC `rua` reports go to
`dmarc.brevo.com` (a third-party aggregator), not an address the owner controls. TLS-RPT was
deliberately pointed at an in-house address (`tlsrpt@ai-servicers.com`, delivered via the
existing `@ai-servicers.com` catch-all → `websurfinmurf@ai-servicers.com`) specifically to
avoid repeating that pattern.

## TLS-RPT — published

```
_smtp._tls.ai-servicers.com  TXT  "v=TLSRPTv1; rua=mailto:tlsrpt@ai-servicers.com"
```

Pure additive record, no enforcement, no failure mode. Reports on TLS negotiation failures
during inbound delivery will land in `tlsrpt@ai-servicers.com`, which resolves via the existing
catch-all alias (`config/postfix-virtual.cf`: `@ai-servicers.com websurfinmurf@ai-servicers.com`)
to the same mailbox the owner already reads. No new mailbox was created.

Verified live via two independent public resolvers (1.1.1.1, 8.8.8.8) after creation.

## MTA-STS — authored, deliberately not published

Policy file (`mode: testing` — enforces nothing, only enables reporting of what *would* have
been blocked) is committed at `mta-sts-policy/.well-known/mta-sts.txt`:

```
version: STSv1
mode: testing
mx: mail.ai-servicers.com
max_age: 86400
```

**Why the `_mta-sts` TXT record was not published:** MTA-STS requires the policy file be
fetchable at `https://mta-sts.ai-servicers.com/.well-known/mta-sts.txt` *before* the TXT record
advertises it — a TXT record pointing at an unreachable policy is worse than no record (senders
that see the `_mta-sts` TXT will fail-closed looking for a policy they can't fetch, per RFC
8461 §3).

Verified 2026-08-01: `mta-sts.ai-servicers.com` currently resolves only via the zone's wildcard
CNAME (`*.ai-servicers.com` → `home.ai-servicers.com` → `108.35.80.85`), which is the home
Traefik/nginx edge. That edge returns HTTP 404 for the `mta-sts.ai-servicers.com` Host header —
there is no router configured for this hostname yet:

```
$ curl -sS -o /dev/null -w "%{http_code}\n" https://mta-sts.ai-servicers.com/.well-known/mta-sts.txt
404
```

### Hosting requirement (follow-up, not done here)

Before the `_mta-sts` TXT record can be published, something must serve
`mta-sts-policy/.well-known/mta-sts.txt` (content above) at exactly
`https://mta-sts.ai-servicers.com/.well-known/mta-sts.txt` over valid HTTPS. Two ways to get
there, both out of scope for this project (this brief explicitly excludes touching
`projects/traefik`):

1. Add a Traefik router + a minimal static file server (or a Traefik file-provider redirect) for
   host `mta-sts.ai-servicers.com`, serving this repo's `mta-sts-policy/` directory. The
   existing wildcard cert (`*.ai-servicers.com`) already covers the hostname — this is a
   Traefik-project routing change only.
2. Alternative: host via the existing `nginx.ai-servicers.com` static-site pattern, if that
   instance can be configured to also answer on the `mta-sts.ai-servicers.com` Host header —
   needs Traefik-side routing regardless, since DNS resolution for `mta-sts.ai-servicers.com`
   is the shared wildcard that reaches whichever backend Traefik picks.

Once hosting is live and `curl https://mta-sts.ai-servicers.com/.well-known/mta-sts.txt` returns
the policy over valid TLS, publish:

```
_mta-sts.ai-servicers.com  TXT  "v=STSv1; id=<any-unique-string, e.g. a timestamp>"
```

Do not set `mode: enforce` in the policy file without an explicit owner decision — same
reasoning as the DMARC gate above: enforcement can silently drop mail from a sender whose config
hasn't been validated yet.

## Why CAA is intentionally absent

Looks like a free additive record. It is not. Certificate Transparency logs show a live
`*.ai-servicers.com` certificate issued by **Google Trust Services** (CN=WE1, expires
2026-09-24) alongside the Let's Encrypt certs this project and others use — that's Cloudflare
Universal SSL for the Cloudflare-proxied apex record. A CAA record authorizing only Let's
Encrypt would break nothing today and **silently kill that renewal ~60 days out**, and
Cloudflare can also rotate its Universal SSL CA at any time. Do not add CAA without accounting
for both issuers.

## Why DNSSEC is intentionally absent

No owner decision has been made to enable it. Out of scope for this brief; not evaluated here
beyond confirming it's currently off.

## Verification commands

```bash
dig +short TXT _smtp._tls.ai-servicers.com @1.1.1.1     # TLS-RPT
dig +short TXT _mta-sts.ai-servicers.com @1.1.1.1        # MTA-STS (expect empty until hosting exists)
dig +short TXT _dmarc.ai-servicers.com @1.1.1.1          # DMARC (must stay p=none until owner decision)
dig +short TXT ai-servicers.com @1.1.1.1                 # SPF
dig +short MX ai-servicers.com @1.1.1.1                  # MX
```

## Source

- Session: `docs/refocus/2026-08-01-mail-tls-reporting-c12924.md`
- DNS provider: Cloudflare, zone `ai-servicers.com` (id `a54b71919164311203515b5b39512976`).
  Read/write via `CF_DNS_API_TOKEN` in `~/projects/secrets/traefik.env` (existing credential,
  not duplicated here).
