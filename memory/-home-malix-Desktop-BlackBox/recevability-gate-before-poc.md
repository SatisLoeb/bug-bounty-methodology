---
name: recevability-gate-before-poc
description: On a un candidat de bug — passer le gate de recevabilité (dup/scope/impact) AVANT d'écrire le PoC, jamais après.
metadata:
  type: feedback
---

Quand un candidat de vulnérabilité émerge, l'utilisateur veut le **gate de recevabilité d'abord** :
audits du projet (clause « known issues previously reported in security audits are out of scope »),
doublons, et surtout **correspondance à une case d'impact réelle du programme**. Le PoC vient après.

**Why:** un PoC coûte des heures, le gate coûte dix minutes et tue souvent la piste. Sur The Graph
(août 2026), le gate a tué deux candidats successifs — un bricking de pool de délégation (aucune case
d'impact : le programme n'a que vol >$1M et impersonation, pas de freezing/DoS) et une capacité gagnée
par auto-délégation (déjà OZ L-14). Deux fois des jours économisés.

**How to apply:** dès qu'un candidat est formulé, avant toute exécution — lire les PDF d'audit du repo
(`packages/*/audits/`, convertis via pdftotext), chercher la classe du bug et pas seulement son identité
exacte, puis vérifier qu'un impact du programme accepte littéralement le résultat. Annoncer le verdict
même quand il est négatif, plutôt que d'habiller une observation en finding. Voir [[deployed-code-not-head]].
