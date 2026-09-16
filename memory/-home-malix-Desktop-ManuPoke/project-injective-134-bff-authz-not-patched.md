---
name: project-injective-134-bff-authz-not-patched
description: "Cantina #134 (Injective BFF authz-grant identity confusion, rejected 3x) verified NOT silently patched as of 2026-07-24 — path structurally live."
metadata:
  node_type: memory
  type: project
  originSessionId: 18f37fbd-b9f1-4054-a4dd-7c210c6f1e52
  modified: 2026-07-29T13:40:12.326Z
---

Operator's own Cantina submission **#134** ("helixapp.com off-chain account takeover via authz-grant
identity confusion") — `POST bff-api.injective.network/api/v1/authorization` with `sender=attacker`,
`granterAddress=victim` mints a JWT `sub=victim` off a single on-chain `MsgBatchUpdateOrders` authz grant.
**Rejected 3×** (Medium→Low→Medium→closed "non-issue" by ak, 2026-06-30). Root defect = grant-TYPE keyed as
identity (MsgBatchUpdateOrders=200 but sibling MsgCreateSpotMarketOrder=401 → mapping defect, not authz-as-designed);
2nd defect = control-of-address-A mints identity-session-for-B.

## Silent-patch check 2026-07-24 → **NOT PATCHED (structurally intact)**
Verified first-party, non-destructive (fresh throwaway key Z I control, signed EIP-191, via Tor, NO grant
broadcast, no real user touched). Server order = nonce-check → sig-check → grant-check. Live results:
- **Probe C** (self-login, no `granterAddress`, valid sig): **200, JWT sub=Z** → endpoint still mints sessions.
- **Probe B** (self, `granterAddress=Z`, no grant): **401 `Authz grant missing or expired`** → presence of
  granterAddress still triggers on-chain grant-lookup.
- **Probe A [diagnostic]** (cross-identity `granterAddress=X`, valid sig, no grant X→Z): **401 `Authz grant
  missing or expired`** = byte-identical to the report's negative control. The team's own suggested fix (bind
  session to *registered auto-sign key*, require sender==registered) would have failed A BEFORE the grant-lookup
  or ignored granterAddress. It didn't → **no structural fix, no new identity guard.**
- **Live victim pop GREW**: bot grantee `inj1a573wahqyjzrpzs2r9egfenmdfynnwgrje9c6f` now holds
  `MsgBatchUpdateOrders` grants from **73 distinct granters** (report tracked 34→41→55→58).
- **admin-api detour still fail-closed**: `admin-api.injective.network/api/v1/authorization` with granterAddress
  → still `500 "Authz grant verification not configured"` (June-28 latent-escalation risk neither wired nor fixed).

## Cantina mod escalation 2026-07-27 → CONFIRMED-DEAD, don't re-try either venue
A sympathetic Cantina moderator (Arjun Rao) re-opened the question 2026-07-24 ("send me the link",
forwarded with "not the first time with injective"). Operator sent a tight chill re-pitch (differential
+ live re-verify + pop 73; file `~/Desktop/BUGS/injective-134-mod-message.md`). Mod checked with the team
AND the client → **2026-07-27 verdict identical: "nothing's changed, tagged as a non-issue."** Both venues
now exhausted: the program team (3× reject) AND the platform mod (after client consult). **NO payable path
for #134 remains on Cantina.** The wall was the client's disposition, not the argument. Disclosure-only value
(finding is real + live). Do NOT re-appeal, do NOT re-ping the mod, do NOT re-derive.

## Unexecuted leg + strategic read
Only link NOT observed = the final `200 sub=victim` on a LIVE MsgBatchUpdateOrders grant — needs broadcasting one
throwaway→throwaway grant tx (operator-funded, on-chain). Everything reachable without it is unchanged, so
high-confidence unpatched but the money-shot isn't executed-proven. **Strategic:** a silent patch would have been
the strongest re-appeal lever (tacit admission of a "non-issue"); its ABSENCE removes that lever. "Still live"
alone does not resurrect a 3×-rejected finding (program may call it accepted-risk). Don't relitigate on weak
ground. Harness ready if operator wants the airtight 200-sub=victim artifact. Scripts: scratchpad/verify134{,b}.py.
