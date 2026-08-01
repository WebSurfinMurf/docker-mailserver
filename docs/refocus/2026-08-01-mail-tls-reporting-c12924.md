---
id: 2026-08-01-mail-tls-reporting-c12924
status: result
child_session_id: c12924ec-8f49-4fc8-b116-6807ccdd5d86
spawn_mode: execute
tier: low
spawned_at: 2026-08-01T00:55:00Z
launched_at: 2026-08-01T01:20:26Z
completed_at: 2026-08-01T01:30:00Z
source_dir: /home/administrator/projects/aws
source_session_id: 6d3304c3-976c-4e69-a644-3d3b7c5f91d5
dest_dir: /home/administrator/projects/docker-mailserver
slug: mail-tls-reporting
parent_refocus_id: null
related_refocus_ids: []
done_when:
  - "A TLS-RPT TXT record is published at _smtp._tls.ai-servicers.com with a valid v=TLSRPTv1 policy and a reporting destination the owner controls, and its presence is verified by a live DNS query"
  - "An MTA-STS policy file is AUTHORED with mode: testing (enforcing nothing), together with written instructions for the HTTPS hosting it requires - but the _mta-sts TXT record is NOT published unless the policy is already reachable over HTTPS"
  - "The mail DNS posture (SPF, DKIM selectors, DMARC, MTA-STS, TLS-RPT) is documented in this project as the canonical record, including which senders are authorized and why"
  - "Every change made is verified by an actual DNS query showing the new state, not merely by an API success response"
out_of_scope:
  - "Do NOT change the DMARC record in any way - moving off p=none is an explicit owner decision that has NOT been made, and three authorized senders could start having mail dropped"
  - "Do NOT set MTA-STS mode to enforce - testing mode only"
  - "Do NOT publish the _mta-sts TXT record if the policy file is not actually reachable at https://mta-sts.ai-servicers.com/.well-known/mta-sts.txt - a TXT record pointing at an unreachable policy is worse than no record"
  - "Do NOT add a CAA record - this looks safe and is NOT; see inherited context"
  - "Do NOT enable DNSSEC"
  - "Do NOT modify the SPF record, the MX record, or any DKIM selector"
  - "Do NOT modify anything under /home/administrator/projects/aws, /home/administrator/projects/traefik or /home/administrator/projects/cicd"
related: []
---

# Brief: Publish TLS-RPT and prepare MTA-STS (testing mode) for ai-servicers.com

## Why this branch exists
A security assessment of the internet-facing surface on 2026-07-31 measured the live mail DNS
posture and found TLS-RPT and MTA-STS both absent. TLS-RPT is a pure additive TXT record with no
failure mode and gives the first visibility into mail TLS delivery failures — currently zero.
MTA-STS in `testing` mode is equally safe by definition (it enforces nothing) but needs an HTTPS-
hosted policy file, so it is prepared here and published only when that hosting exists.

## Inherited context
- Measured live state 2026-07-31: **SPF present** (`v=spf1 a:mail.ai-servicers.com
  include:sendinblue.com ~all`); **DKIM present** (selectors `mail` and `s1`); **DMARC present but
  `p=none`** with `rua=mailto:rua@dmarc.brevo.com`; **MTA-STS absent**; **TLS-RPT absent**;
  **CAA absent**; **DNSSEC absent**; MX is `10 mail.ai-servicers.com` → `34.194.247.228`.
- The MX cutover from Cloudflare Email Routing to the AWS mail edge **already happened**
  (2026-07-28). `docs/mx-rollback-2026-07-28.md` in the `aws` repo is the rollback record.
- **DMARC is deliberately excluded from this brief.** It is the highest-severity finding
  (`p=none` enforces nothing, and reports go to a third-party aggregator rather than the owner),
  but the domain has **three** authorized senders — the home server's own `mail` selector,
  SendGrid (`s1`/`s2._domainkey`, `em903`), and Brevo (`brevo1`/`brevo2._domainkey`). Enforcing
  before alignment is confirmed would drop legitimate mail. The owner has this decision.
- **CAA is explicitly forbidden here, and it is a trap.** It looks like a free additive record. It
  is not: Certificate Transparency shows a live `*.ai-servicers.com` certificate issued by
  **Google Trust Services** (CN=WE1, expires 2026-09-24) alongside the Let's Encrypt certs — that
  is Cloudflare Universal SSL for the Cloudflare-proxied apex. A CAA record authorizing only
  Let's Encrypt breaks nothing today and **silently kills that renewal ~60 days out.** Cloudflare
  can also rotate its Universal SSL CA. Leave CAA alone.
- Cloudflare is the DNS provider. A read-capable API token exists at
  `~/projects/secrets/traefik.env`; use the project's own established credential path and **never
  write a credential into any repo.**
- The whole zone is only **16 records** — verified by enumeration. It is small; changes are easy to
  see and easy to reverse.
- Ordering matters for MTA-STS: the policy must be reachable at
  `https://mta-sts.ai-servicers.com/.well-known/mta-sts.txt` **before** the `_mta-sts` TXT record
  is published. Publishing the TXT first advertises a policy that cannot be fetched.

## Open questions / desired deliverables
1. TLS-RPT record published and verified live. Choose a reporting destination the owner controls —
   the owner's own address, not a third-party aggregator (the DMARC record's current dependence on
   `dmarc.brevo.com` is precisely the pattern to avoid repeating).
2. MTA-STS policy authored in `testing` mode, with the hosting requirement written down. If the
   HTTPS route does not exist, surface it as a follow-up rather than improvising one.
3. Canonical documentation of the mail DNS posture in this project, including the three-sender
   situation and why DMARC enforcement is pending.
4. Verify every change with a live DNS query.

## Hard rule for child
- Children are leaves. If you discover work that belongs in a different
  directory, do NOT call /refocus. Surface it in Result.suggested_follow_ups
  for the parent to decide.

## Pointer back
- Source session: `~/.claude/projects/-home-administrator-projects-aws/6d3304c3-976c-4e69-a644-3d3b7c5f91d5.jsonl`
- To resume this child's session: `cd /home/administrator/projects/docker-mailserver && claude --resume c12924ec-8f49-4fc8-b116-6807ccdd5d86` — ordinary resume; works the same whether this child was parent-auto-spawned (execute), hand-launched, or headless.

---

## Result

### Status
- completed

### Definition-of-Done met
- ✅ TLS-RPT TXT record published at `_smtp._tls.ai-servicers.com` (`v=TLSRPTv1; rua=mailto:tlsrpt@ai-servicers.com`) and verified live via two independent public resolvers (1.1.1.1, 8.8.8.8).
- ✅ MTA-STS policy authored (`mode: testing`) at `mta-sts-policy/.well-known/mta-sts.txt`, with hosting instructions written in `docs/mail-dns-posture.md`. The `_mta-sts` TXT record was deliberately **not** published — live `curl` to `https://mta-sts.ai-servicers.com/.well-known/mta-sts.txt` returned HTTP 404 (the wildcard CNAME reaches the home Traefik edge, but no router exists for that hostname), so publishing the TXT record now would advertise an unreachable policy.
- ✅ Mail DNS posture documented canonically in `docs/mail-dns-posture.md`: SPF, DKIM selectors (mail/s1/s2/brevo1/brevo2), DMARC (`p=none`, why it stays that way — three authorized senders), MTA-STS, TLS-RPT, and explicit rationale for leaving CAA and DNSSEC absent.
- ✅ Every change verified by live query, not API response alone: TLS-RPT via `dig @1.1.1.1`/`@8.8.8.8`; MTA-STS hosting absence via `curl` HTTP 404; full zone enumerated via Cloudflare API (16 records, matches inherited context) before any write.

### Summary
Published a TLS-RPT record pointing at an in-house mailbox (`tlsrpt@ai-servicers.com`, resolved via the existing `@ai-servicers.com` catch-all to `websurfinmurf@ai-servicers.com` — no third-party aggregator, no new mailbox). Authored an MTA-STS policy in testing mode but confirmed via live HTTPS request that `mta-sts.ai-servicers.com` has no Traefik router yet (404), so per the brief's explicit ordering rule the `_mta-sts` TXT record was withheld — publishing it now would have advertised a policy nothing can fetch. Wrote `docs/mail-dns-posture.md` as the canonical mail DNS record, covering all five controls plus the CAA/DNSSEC exclusion rationale carried over from the brief. All out-of-scope items (DMARC, CAA, DNSSEC, SPF/MX/DKIM, aws/traefik/cicd directories) were left untouched. Changes committed and pushed to `origin/main` (`32faa88`).

### Artifacts produced
- `docs/mail-dns-posture.md` — canonical mail DNS posture record (SPF/DKIM/DMARC/MTA-STS/TLS-RPT, three-sender rationale, CAA/DNSSEC exclusion rationale, verification commands).
- `mta-sts-policy/.well-known/mta-sts.txt` — MTA-STS policy file, `mode: testing`, ready to be served once hosting exists.
- `_smtp._tls.ai-servicers.com` TXT record — live in Cloudflare (zone `ai-servicers.com`).

### Suggested follow-ups (parent decides)
- **`~/projects/traefik`**, slug `mta-sts-policy-hosting` — add a Traefik router (+ minimal static file server, or file-provider route) for host `mta-sts.ai-servicers.com` serving this repo's `mta-sts-policy/.well-known/mta-sts.txt` over the existing wildcard cert. Once live, publish `_mta-sts.ai-servicers.com TXT "v=STSv1; id=<unique>"` — a one-line Cloudflare API call, not itself a Traefik change, but gated on Traefik's routing landing first.
- No other cross-directory work surfaced. DMARC enforcement remains an explicit owner decision (per `out_of_scope`), not a follow-up to auto-spawn.

### Material changes (for /context-save)
- **interfaces or architecture** (`docs/context/`): the mail DNS posture (SPF/DKIM/DMARC/MTA-STS/TLS-RPT, three authorized senders, CAA/DNSSEC exclusion) is now canonical at `docs/mail-dns-posture.md` — worth a one-line pointer from `docs/context/architecture.md` or `interfaces.md` so future sessions discover it without grepping `docs/`.
- **gotchas**: MTA-STS hosting is blocked on a Traefik-side router for `mta-sts.ai-servicers.com` that doesn't exist yet (wildcard CNAME resolves but 404s) — this is the reason the `_mta-sts` TXT record isn't published; a future session should not "fix" this by publishing the TXT record without first confirming the hosting follow-up landed.

<!--
When the child completes, /refocus-complete appends here:

### Status
- completed       # met all done_when criteria
- blocked         # hit a blocker requiring work in another directory; parent must orchestrate

### Definition-of-Done met
<checklist matching done_when from frontmatter, each item checked or noted as not met>

### Summary
<one paragraph: what was accomplished or where it blocked>

### Artifacts produced
- `<path>` — `<one-line description>`

### Suggested follow-ups (parent decides)
<bullets of "I noticed work belongs at <dir>" items the child surfaced for
parent to orchestrate. Each entry: dir, slug, one-line reason.>

### Material changes (for /context-save)
<list of decisions, contracts, or architecture changes that should be
promoted into <dest>/docs/context/* as canonical state. Each entry: which
context file (architecture | interfaces | conventions | gotchas | …) and
the one-line summary. Or: "N/A — investigation only, no canonical state
changed." Mandatory; child must enumerate explicitly before status flips.>

### Child session
- Session jsonl: `~/.claude/projects/-home-administrator-projects-docker-mailserver/c12924ec-8f49-4fc8-b116-6807ccdd5d86.jsonl`
- Completed at: <ISO ts>
-->
