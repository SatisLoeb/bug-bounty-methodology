---
name: vdp-recon-securitytxt-thin-primitive
description: "Mesuré 2026-07-31 — security.txt ne couvre que 5% de l'univers DefiLlama ; le pipeline VDP recon vit dans /home/malix/Downloads/files/"
metadata: 
  node_type: memory
  type: project
  originSessionId: 249ac207-51b5-47ab-8ba5-f810d107f76e
  modified: 2026-07-31T15:52:46.443Z
---

Pipeline VDP recon dans `/home/malix/Downloads/files/` : `github_vdp_scan.py`,
`defillama_gap.py` (réécrit v2 sur l'axe Policy), `securitytxt_check.py`.
Sortie du sweep complet : `channels_full.json` (1233 domaines).

**Calibration mesurée (sweep complet 2026-07-31, TVL ≥ $500k) :**
- 1591 protocoles → 1233 domaines uniques → **65 seulement publient un security.txt (5.3%)**
- PLATFORM 15 · SELF_VDP 21 · CONTACT_NO_POLICY 29 · NO_SECURITY_TXT 1169 · NO_URL 117
- 11 security.txt EXPIRÉS (Expires dépassé ⇒ safe harbor non engagé)

**Conséquence pour le sourcing :** security.txt est une primitive de découverte
MINCE sur le gros DeFi — l'apex renvoie 404 pour aave/morpho/sky/base/uniswap.
Le canal réel vit sur la fiche plateforme ou une page docs, pas dans RFC 9116.
Ne pas re-dériver ça : le bucket qui porte le signal est SELF_VDP (21 lignes),
et il sélectionne pour `p_bounty` faible par construction — cohérent avec
[[ev-gate-check-program-responsiveness-not-just-severity]] et
[[feedback-target-diet-is-the-binding-constraint]] : utile pour GHSA/acks, pas
pour du cash.

**v1 était cassé (mesuré) :** la jointure slug DefiLlama ↔ slug Immunefi donnait
25 matches sur 1591 → 98.4% de faux « gap » (aave-v3 $13.6B classé « pas de
bounty » parce que `aave-v3` != `aave`). v2 classe par le host trouvé dans
Policy/Contact/Canonical — zéro matching de nom.

**Limite résiduelle connue :** la détection de plateforme est par HOST. Une
Policy qui décrit le programme en prose passe à travers (binance.com mentionne
Bugcrowd en texte, grvt.io dit « private program on Bugcrowd only »). Le champ
`prose_platform_hints` expose l'indice sans reclasser — à lire au triage.
