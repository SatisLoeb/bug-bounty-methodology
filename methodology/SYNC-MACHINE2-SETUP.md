# Machine 2 (Kali) — Setup pour sync avec le VPS Forgejo

Procédure pour rendre une machine Kali Linux opérationnelle et synchronisée
avec le VPS `srv1683579.hstgr.cloud` qui héberge Forgejo + restic-rest-server.

À la fin de cette procédure, machine 2 peut travailler activement et
synchroniser avec un seul `./scripts/sync-from-vps.sh`.

---

## Pré-requis machine 2

- Kali Linux (Ubuntu/Debian-based)
- User `malix` (ou ajuster les chemins dans le script)
- Connexion internet
- Paquets : `git`, `curl`, `python3`, `bunzip2` (préinstallés sur Kali standard)

```bash
sudo apt update && sudo apt install -y git curl python3 bzip2
```

---

## Étape 1 — Cloner le repo BUGS depuis le VPS

D'abord il faut un token Forgejo pour cloner. Sur machine 1, générer un
token dédié machine 2 :

```bash
# Sur machine 1
ssh malix@72.62.176.175 'sudo docker exec -u git forgejo \
    gitea admin user generate-access-token \
    --username malix \
    --token-name machine2 \
    --scopes all'
# → Note le token affiché (40 char hex). Il ne sera plus affiché.
```

Sur machine 2 — configurer le credential helper, puis cloner :

```bash
mkdir -p ~/.config/git && chmod 700 ~/.config/git
cat > ~/.config/git/credentials <<EOF
https://malix:<TOKEN_MACHINE2>@srv1683579.hstgr.cloud
EOF
chmod 600 ~/.config/git/credentials
git config --global credential.helper "store --file=$HOME/.config/git/credentials"

# Cloner BUGS et arsenal-remote
git clone https://srv1683579.hstgr.cloud/malix/bugs.git ~/Desktop/BUGS
git clone https://srv1683579.hstgr.cloud/malix/arsenal-remote.git ~/arsenal

# Renommer le remote arsenal pour matcher le script
cd ~/arsenal
git remote rename origin backup
```

---

## Étape 2 — Récupérer les secrets restic

Les deux mots de passe restic ne sont **PAS** dans git (et ne doivent jamais
l'être). Il faut les copier manuellement depuis machine 1.

**Sur machine 1**, exporter les deux secrets vers une clé USB chiffrée
(ou via `scp` direct si machine 2 est joignable) :

```bash
# Option A — clé USB
cp ~/.restic-password /media/usb/restic-password
cp ~/.vps/restic-rest-pw /media/usb/restic-rest-pw
sync && eject /media/usb

# Option B — scp direct si machine 2 a SSH ouvert
scp ~/.restic-password malix@machine2:~/.restic-password
scp ~/.vps/restic-rest-pw malix@machine2:~/.vps/restic-rest-pw
```

**Sur machine 2** — installer les secrets avec les bonnes permissions :

```bash
mkdir -p ~/.vps && chmod 700 ~/.vps

# Si clé USB
cp /media/usb/restic-password ~/.restic-password
cp /media/usb/restic-rest-pw ~/.vps/restic-rest-pw

chmod 600 ~/.restic-password ~/.vps/restic-rest-pw
```

**ATTENTION** : `~/.restic-password` est la clé de chiffrement du backup.
Si tu la perds, tous les snapshots restic deviennent illisibles. Elle doit
exister aussi en copie offline (papier, password manager).

---

## Étape 3 — Init du script de sync

```bash
cd ~/Desktop/BUGS
./scripts/sync-from-vps.sh init
```

Le script va :
- Télécharger `restic` binaire dans `~/bin/`
- Créer `~/.cache/` pour les fichiers de staging et de tracking
- Afficher les étapes manuelles restantes (que tu as déjà faites en 1 et 2)

---

## Étape 4 — Premier pull

```bash
cd ~/Desktop/BUGS
./scripts/sync-from-vps.sh status  # voir l'état sans rien modifier
./scripts/sync-from-vps.sh pull    # premier pull complet
```

Ce que ça fait :
- `git pull` sur `~/arsenal` et `~/Desktop/BUGS`
- `restic restore` du dernier snapshot vers `~/.cache/sync-restore-staging/`
- Merge mtime-aware vers `~/.claude/` et `~/Desktop/CLAUDE.md`
- Skip des paths machine-2-specific (sessions Claude, shell-snapshots, etc.)

Vérifier qu'on a bien `~/.claude/projects/-home-malix-Desktop-BUGS/memory/MEMORY.md`.

---

## Étape 5 — Utilisation quotidienne

```bash
# Avant de bosser : récupérer les dernières modifs machine 1
./scripts/sync-from-vps.sh pull

# Pendant le boulot : tu commit comme d'habitude dans ~/arsenal et ~/Desktop/BUGS
git add -A && git commit -m "wip"

# À la fin de session : pousser
./scripts/sync-from-vps.sh push

# Ou en un coup : pull + push
./scripts/sync-from-vps.sh sync
```

**Recommandation forte** : faire un `pull` avant de commencer toute session
sérieuse, et un `push` avant de fermer la machine. Sinon tu vas diverger et
le rebase deviendra douloureux.

---

## Gestion des conflits

### Conflits git (sur les `.md`, `.sh`, fichiers versionnés)

Si le rebase échoue pendant un pull :

```bash
# Le script s'arrête et te dit quoi faire :
cd ~/Desktop/BUGS  # ou ~/arsenal
git status         # voir les fichiers en conflit
# Édite les fichiers, garde ce qui doit être gardé
git add <fichier>
git rebase --continue
```

Si tu veux annuler le rebase et tout réessayer :

```bash
git rebase --abort
git stash pop  # récupère ton travail auto-stashé
```

### Conflits restic (sur les fichiers non-git, ex: `.claude/`)

Quand un fichier remote est plus récent ET ton fichier local a été modifié
depuis le dernier sync, le script :
- Sauve ton local en `<fichier>.conflict-<timestamp>`
- Applique la version remote
- Te le signale dans le log

Tu peux ensuite comparer :

```bash
diff ~/.claude/projects/.../memory/MEMORY.md \
     ~/.claude/projects/.../memory/MEMORY.md.conflict-1779170920
```

Et merge manuellement la version qui convient.

---

## Si tu casses quelque chose

### Restaurer un fichier depuis un snapshot précédent

```bash
~/bin/restic snapshots
# Note le short_id du snapshot voulu (ex: 50b5183d)

~/bin/restic restore 50b5183d --target /tmp/restore \
    --include /home/malix/Desktop/BUGS/path/to/file.md
# Récupère le fichier depuis /tmp/restore/
```

### Reset complet d'un repo git sur la version remote

```bash
cd ~/arsenal  # ou ~/Desktop/BUGS
git fetch --all
git reset --hard backup/main  # arsenal
# OU
git reset --hard origin/main  # BUGS

# ⚠️ Détruit tout travail local non poussé.
```

---

## Sécurité

- **Le token Forgejo machine 2 est différent de machine 1.** Si machine 2 est
  perdue/volée, révoquer uniquement le token machine 2 :
  ```bash
  ssh malix@72.62.176.175 'sudo docker exec -u git forgejo \
      gitea admin user delete-access-token \
      --username malix --token-name machine2'
  ```
- Le password rest-server `backup-user` est partagé entre les machines.
  Si une machine est compromise, rotation côté VPS :
  ```bash
  # Sur le VPS
  sudo htpasswd -B /opt/restic-server/auth/.htpasswd backup-user
  # Puis distribuer le nouveau password sur les machines de confiance
  ```
- Le restic encryption password (`~/.restic-password`) est partagé entre
  toutes les machines. Pour le rotater, il faut `restic key add` puis
  `restic key remove` après vérification.

---

## Fichiers créés sur machine 2

Après setup complet :

```
~/Desktop/BUGS/                  # repo git cloné
~/arsenal/                       # repo git cloné
~/.claude/                       # restauré depuis restic
~/Desktop/CLAUDE.md              # restauré depuis restic
~/bin/restic                     # binaire installé par init
~/.restic-password               # secret 600, copié de machine 1
~/.vps/restic-rest-pw            # secret 600, copié de machine 1
~/.config/git/credentials        # secret 600, contient le token Forgejo m2
~/sync-history.log               # historique des syncs (masking creds)
~/.cache/sync-last-time          # epoch du dernier sync (anti-clobber)
```

---

## Voir aussi

- `scripts/sync-from-vps.sh` — le script de sync lui-même
- `scripts/backup-restic.sh` — backup direct vers VPS (sans pull)
