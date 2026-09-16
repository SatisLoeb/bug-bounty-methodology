---
name: vercel-sandbox-target-state
description: Vercel Sandbox Escape Challenge (HackerOne) intake — NO-GO/RE-SOURCE for a solo SC/web profile
metadata: 
  node_type: memory
  type: project
  originSessionId: 350f94b8-d797-4d13-9c3b-5d74ead00356
  modified: 2026-08-22T09:34:54.541Z
---

Vercel Sandbox Escape Challenge (HackerOne public, $1M pool, max $50k/report). Window 18-aug→1-sep 2026, triage jusqu'au 1-oct. Intake 2026-08-22 (fan-out 6 agents sur Opus-4-8 — fallback classifieur offensive-sec, jamais Opus-5, cf [[subagent-model-routing]]).

**VERDICT = NO-GO / RE-SOURCE pour le profil (SC-primary + web/API-secondaire). 0 GO clean sur 6 surfaces (2 NOGO, 4 THIN).**

3 gates décisifs, indépendants de la technique :
1. **Discipline-mismatch** : les 2 surfaces haut-plafond (Firecracker→host escape Critical $25-50k ; cross-tenant DoS High $10-25k) = feasibility 1/5, pur 0-day Rust-VMM derrière jailer+seccomp / oracle co-location micro-arch. Zéro transfert SC/Foundry. Tous les known-findings pré-divulgués (core_pattern, modprobe, mknod /dev/vda) posent uid0 DANS le guest (kernel propre à la microVM) = classe container→guest **explicitement OOS**.
2. **Dup-wall extrême** = [[farmed-program-dup-baserate]] au max : 748 rapports en ~4 jours, 0 résolu, 1 thanked (rep 0). Paysage dup invisible (triage pas passé). Corpus classique egress-bypass **pré-divulgué OOS** dans docs firewall 2026-08-04 (SNI≠Host, IP-literal+resolver, subnets.allow→DNS libre, wildcard-depth). Modèle allow-only → normalization-mismatch échoue FERMÉ (self-DoS, pas bypass).
3. **Fenêtre 10 j** : tout payable = harness fuzzing virtio / RE vsock RPC / repro escape kernel / oracle co-location (semaines) OU batterie probes web-fit déjà sur-tapée.

Surfaces (plafond réaliste toi / feas / dup / verdict) :
- Control-plane API IDOR/BOLA : Low$1-5k(Crit théorique) / 4 / 5 / THIN — projectId confused-deputy + authz-drift v2/v3/v4 + précédence OIDC. Middleware team/project durci années.
- Cred-brokering + MMDS : Low / 4 / 4 / THIN — network-policy BOLA (echo injectionRules) + in-guest token hygiene. MMDS=mirage dupé.
- Firewall egress : Low / 4 / 5 / THIN — 3 angles restants (survie connexion live-update, SNI-vs-orig-dst, QNAME DNS leak).
- Known-primitive→new-impact (vsock 2050 OCI-config-write/cache-oracle/proxy-CA/Ed25519) : Crit plafond / 2 / 5 / THIN — gated par repro escape off-profile.
- Firecracker→host : Crit / 1 / 5 / **NOGO**.
- Cross-tenant DoS : High / 1 / 5 / **NOGO**.

Si shot loterie (Low, timebox 1-2j, ~$20 Pro, drop au 1er dup) : gate-closers A=`lspci`/sysfs/dmesg (PCI vs MMIO→tue CVE-2026-5747), B=AF_VSOCK CID2:2050 depuis container ; puis web-fit C=BOLA matrix 2 comptes, D=cred-hygiene sweep /proc/environ+JWT, E=firewall 3-angles, F=MMDS deny-all.

Caveats à VÉRIFIER live (agents ont inféré) : chemins REST + echo injectionRules (openapi.vercel.sh) ; CVE-2026-5747/1386 post-cutoff = leads pas faits ; docs firewall 2026-08-04 = le gate OOS, lire soi-même. Voir [[recevability-gate-before-poc]], [[measure-before-asserting-in-reports]].
