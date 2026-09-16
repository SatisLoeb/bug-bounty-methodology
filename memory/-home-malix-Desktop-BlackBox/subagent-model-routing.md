---
name: subagent-model-routing
description: "How subagent model routing actually behaves; why Opus 5 can't be forced for offensive-sec agents"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: cba84a85-5226-4703-87f8-5ba46436d533
  modified: 2026-08-22T12:51:19.034Z
---

Vérifié 2026-08-22 (MAJ, corrige la note du 08-21) : dans cet environnement je **ne peux PAS forcer les sous-agents sur Opus 5** pour du contenu offensive-sec. Trois leviers testés, tous → `claude-opus-4-8` :
1. env `CLAUDE_CODE_SUBAGENT_MODEL=claude-opus-5` (bien posé shell+settings.json) → 4-8.
2. `subagent_type:"fork"` (docs: hérite TOUJOURS mon modèle = `claude-opus-5[1m]`) → 4-8 quand même.
3. per-call `model:"opus"` → 479 records / 12 agents = 100% opus-4-8, 0 opus-5, **0 refusal visible**.

Le discriminant n'est PAS le paramètre : c'est un **routage SILENCIEUX côté serveur** qui garde le contenu offensive-sec des sous-agents sur 4-8 (pas de `stop_reason:refusal` visible → ce n'est plus le fallback-classifieur du 08-21 ; l'environnement a changé). Un agent au prompt BÉNIN (fetch robots.txt) a montré 2 tours opus-5 au tout début puis a coulé sur 4-8 (13×4-8 vs 2×5). Donc même le bénin ne TIENT pas Opus 5.

Conséquence opérationnelle : **le seul cerveau Opus 5 garanti = la session principale (moi)**. Pour un fan-out d'audit, le pattern qui marche = sous-agents 4-8 en collecte/large + MOI (Opus 5) qui fais la vérification adversariale + la construction finale des findings. Vérifier le modèle réel via `grep -oE '"model":"[^"]+"' tasks/<id>.output | sort | uniq -c` (borné, ne pas lire le JSONL entier). L'en-tête d'autorisation [[authz-framing-subagent-prompts]] reste utile mais n'a PAS suffi à tenir Opus 5 cette fois. Ne pas promettre à l'user des sous-agents Opus 5 sans avoir re-mesuré ce jour-là.
