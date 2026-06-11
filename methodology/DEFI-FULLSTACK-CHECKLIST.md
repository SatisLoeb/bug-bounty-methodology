# DeFi Full-Stack Hunt Checklist

Systematic checklist covering ALL attack surfaces of a modern DeFi protocol: API, frontend, infrastructure, smart contracts, key management. Derived from the Upshift recon methodology (40 findings, $332M TVL, $0 attack cost fund theft chain).

**This is the MASTER checklist.** It references domain-specific checklists for deep dives:
- `CRITICAL-HUNT-CHECKLIST.md` — Smart contract patterns (EVM)
- `SOLANA-HUNT-CHECKLIST.md` — Solana/Anchor patterns
- `NEXTJS-HUNT-CHECKLIST.md` — Next.js/RSC patterns
- `WEB-API-CHECKLIST.md` (in gravedigger skill) — Web/API deep dive

**Activate for:** Any DeFi protocol with a web app, backend API, AND smart contracts.

**Time budget:** 15-25h total. If 0 findings after 8h of scanning, MOVE ON.

---

## F0. RECON & FINGERPRINTING (30 min)

### F0.1 Protocol Identity

```bash
# TVL
curl -s "https://api.llama.fi/protocol/{slug}" | jq '{name, tvl, chains, chainTvls}'

# Chains deployed
curl -s "https://api.llama.fi/protocol/{slug}" | jq '.chainTvls | keys'
```

- [ ] **TVL par chain** documenté (DeFiLlama)
- [ ] **Audits** téléchargés — lire les "acknowledged/wontfix" (= or pour chercheur)
- [ ] **Contact sécurité** identifié (security.txt → SECURITY.md → security@ → bounty → social)

### F0.2 Tech Stack Detection

```bash
TARGET="https://{app_domain}"
API="https://{api_domain}"

# Frontend framework
curl -sI "${TARGET}" | grep -iE 'x-powered-by|server'
curl -s "${TARGET}" | grep -oE '__NEXT_DATA__|__nuxt|__svelte|ng-version|_app.*\.js'
curl -s "${TARGET}" | grep -oE '/_next/|/_nuxt/|/build/|/assets/' | head -3

# Backend framework
curl -sI "${API}/" | grep -iE 'server:|x-powered-by'
curl -s "${API}/nonexistent" 2>/dev/null | head -20  # Error format reveals framework

# Database hints
curl -s "${API}/health" 2>/dev/null | grep -iE 'mongo|postgres|redis|mysql|dynamo'
```

- [ ] **Frontend**: Framework + version + hosting (Vercel/Cloudflare/S3/custom)
- [ ] **Backend**: Framework + language (FastAPI/Express/Go/Rust)
- [ ] **Database**: Type(s) identifié(s) (PostgreSQL, MongoDB, Redis, etc.)
- [ ] **Hosting/CDN**: Provider identifié (AWS/GCP/Vercel/Cloudflare)
- [ ] **Si Next.js détecté** → activer `NEXTJS-HUNT-CHECKLIST.md`

### F0.3 Domain Enumeration

```bash
DOMAIN="{domain}"

# Subdomains
for sub in api app admin staging dev test beta dashboard docs blog status monitor backend private internal legacy old v1 v2 prices ws graphql; do
  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "https://${sub}.${DOMAIN}/" 2>/dev/null)
  [ "$code" != "000" ] && echo "$code ${sub}.${DOMAIN}"
done

# Certificate Transparency
curl -s "https://crt.sh/?q=%25.${DOMAIN}&output=json" | jq -r '.[].name_value' 2>/dev/null | sort -u

# Legacy/rebrand domains (check WHOIS, web search for "{protocol} formerly known as")
# Check if legacy domains still resolve AND still serve content
```

- [ ] **Subdomains actifs** listés (api, app, admin, staging, dev, backend, private, prices, ...)
- [ ] **Domaines legacy** trouvés (rebranding, anciens noms comme augustdigital.io pour Upshift)
- [ ] **Staging/dev** backends accessibles publiquement ?
- [ ] **Mirrors** servant le même backend ? (tester GET /health sur chaque domaine)

---

## F1. API SURFACE (60 min)

### F1.1 OpenAPI / Swagger Discovery

```bash
API="https://{api_domain}"

for path in /openapi.json /openapi.yaml /swagger.json /swagger.yaml /api/openapi.json /api/v1/openapi.json /api/v2/openapi.json /docs /api-docs /swagger-ui /redoc; do
  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "${API}${path}")
  [ "$code" != "000" ] && [ "$code" != "404" ] && echo "[OPENAPI] $code $path"
done

# Si trouvé, sauvegarder et analyser
curl -s "${API}/openapi.json" | jq '.paths | keys | length' 2>/dev/null  # Nombre d'endpoints
curl -s "${API}/openapi.json" | jq '[.paths[][]] | map(select(.security == [] or .security == null)) | length' 2>/dev/null  # Endpoints sans auth
```

- [ ] **OpenAPI spec accessible** — si oui, compter endpoints totaux vs endpoints sans auth
- [ ] **Swagger UI accessible** sans auth (/docs, /swagger-ui)
- [ ] **Spec sauvegardée** dans evidence/web/

### F1.2 Endpoint Auth Classification

```bash
# Pour CHAQUE endpoint découvert, classifier :
# 1. Sans token -> quel HTTP code ?
# 2. Avec token invalide -> quel HTTP code ?
# 3. Avec token valide -> quel HTTP code ?

# Unauthenticated scan (bulk)
for endpoint in $(cat endpoints.txt); do
  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "${API}${endpoint}")
  echo "$code $endpoint"
done | sort > auth-classification.txt

# Compter les endpoints accessibles sans auth
grep "^200\|^201\|^301\|^302" auth-classification.txt | wc -l
```

- [ ] **Endpoints sans auth** listés et catégorisés (lecture seule vs écriture)
- [ ] **Endpoints d'écriture sans auth** = CRITICAL (like Upshift W1, W4, W17, W29)
- [ ] **Endpoints admin/debug sans auth** = CRITICAL (like Upshift W11, W32)

### F1.3 Unauthenticated Write Endpoints (Fund Theft Vector)

```bash
# Tester CHAQUE endpoint POST/PUT/PATCH/DELETE découvert SANS authentification
# Chercher spécifiquement les patterns dangereux :

# On-chain trigger sans auth (like Upshift W1)
curl -s -X POST "${API}/integrations/methods" -H "Content-Type: application/json" \
  -d '{"chain_id":1,"target":"0x...","selector":"0x..."}' | head -20

# Database write sans auth (like Upshift W17)
curl -s -X POST "${API}/integrations/otc" -H "Content-Type: application/json" \
  -d '{"test":"probe"}' | head -20

# Configuration write sans auth
curl -s -X POST "${API}/config" -H "Content-Type: application/json" \
  -d '{"test":"probe"}' | head -20
```

- [ ] **Aucun endpoint POST/PUT n'est accessible sans auth** — si un seul l'est → finding critique
- [ ] **Endpoints qui triggerent des tx on-chain** vérifiés → auth obligatoire
- [ ] **Endpoints qui écrivent en DB** vérifiés → auth obligatoire
- [ ] **Lambda/serverless endpoints** découverts et testés (souvent déployés hors du middleware auth principal)

### F1.4 Auth Mechanism Deep Testing

```bash
# OAuth2 / Password Grant
curl -s -X POST "${API}/auth/login" -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin"}' | head -20

# SIWE — tester compliance EIP-4361 (8 champs obligatoires)
# → Voir DEEP-ANALYSIS-PLAYBOOK.md §4.1

# API Key
curl -s "${API}/endpoint" -H "x-api-key: test" | head -20
curl -s "${API}/endpoint" -H "Authorization: Bearer test" | head -20

# Nonce statique ?
for i in $(seq 1 5); do curl -s "${API}/auth/nonce?address=0x0000000000000000000000000000000000000001" | jq -r '.nonce'; done
```

- [ ] **SIWE compliance** : 8/8 champs validés côté serveur ? (domain, address, uri, version, chain-id, nonce, issued-at, expiration)
- [ ] **Nonce rotation** : le nonce change-t-il après chaque auth ? (statique = replay permanent, like Upshift W16)
- [ ] **Rate limiting** sur login : bloquer après N tentatives ? (absent = brute force, like Upshift W10)
- [ ] **JWT validation — AUTOMATED par JWT Arsenal** : Si JWT détecté, lancer l'arsenal automatiquement :
  ```bash
  cd ~/Desktop/BUGS/jwt-nullgate-research/jwt-arsenal && source ../pocs/.venv/bin/activate
  python3 -m pipeline.runner --lib "{library}" --source "{source_path}" --tools "1,2,3,4,5,6,7,8" -v
  ```
  L'arsenal teste automatiquement : alg confusion (PEM+DER), null-gate bypass, JWK auto-trust, header injection, RFC compliance, algorithm fuzzing (12 transitions), cross-library differential (8 libs, 5 langages, 45+ tokens adversariaux). Remplace ~5h de tests manuels par ~35min automatisé. Voir `JWT-ARSENAL-PLAYBOOK.md` dans le skill gravedigger.
- [ ] **JWT null-gate bypass (CVE-2026-29000)** : **Arsenal Tool 1 + Tool 7 (T06, T07)**. Si JWE+JWS, PlainJWT dans JWE → `toSignedJWT()` retourne null → verification sautée. Aussi `alg:none`, type confusion token
- [ ] **JWK header auto-trust (AUTH-001, RFC 8725 §2.4)** : **Arsenal Tool 6 + Tool 7 (T07) + Tool 3 (RFC 8725 §2.4)**. Ref: Authlib <= 1.6.8
- [ ] **DER algorithm confusion (JOSE-001, CVE-2024-33663 bypass)** : **Arsenal Tool 5 (TR-002) + Tool 7 (T04) + Tool 8 (JOSE-001 mapping)**. Ref: python-jose toutes versions. Libs sûres : PyJWT 2.11+, go-jose/v4, lestrrat-go/jwx v3
- [ ] **Layered security type confusion** : Chaque couche de sécurité (chiffrement, signature, validation claims) est-elle indépendante ? **Arsenal Tool 2 (pipeline tracer) + Tool 4 (key provenance)** détectent les couplages et bypass paths automatiquement

### F1.5 Data Exposure Endpoints

```bash
# Endpoints qui leakent des données sensibles sans auth
for path in /users /user /accounts /subaccounts /vaults /positions /balances /leaderboard /points /pending-redemptions /roles /configs /health /metrics /threads /sentry-debug /debug; do
  resp=$(curl -s -w "\n%{http_code}" "${API}${path}" 2>/dev/null)
  code=$(echo "$resp" | tail -1)
  [ "$code" = "200" ] && echo "[LEAK] $path" && echo "$resp" | head -5
done

# Pagination abuse (like Upshift W18 — 61,776 addresses via leaderboard)
curl -s "${API}/leaderboard?limit=100&offset=0" | jq 'length'
```

- [ ] **User enumeration** possible sans auth ?
- [ ] **Balances/positions** exposées sans auth ?
- [ ] **RBAC/roles** exposés sans auth ? (like Upshift W9 — 2,212 roles)
- [ ] **Health/debug** endpoints avec info infrastructure ?
- [ ] **Pagination** permet l'extraction complète des données ?

### F1.6 OAuth2/OIDC State Machine (auto-activé si détecté)

```bash
# Détection OAuth2/OIDC
curl -s "${API}/.well-known/openid-configuration" | jq '{issuer, authorization_endpoint, token_endpoint, jwks_uri}' 2>/dev/null
for path in /oauth/authorize /authorize /oauth/token /token /oauth/callback /callback; do
  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "${API}${path}" 2>/dev/null)
  [ "$code" != "000" ] && [ "$code" != "404" ] && echo "[OAUTH] $code $path"
done
grep -oP 'client_id["\s:=]+["\x27]([a-zA-Z0-9._-]+)["\x27]' evidence/web/js-bundles/all-bundles.js 2>/dev/null
```

Si OAuth détecté → **lire `OAUTH2-OIDC-PLAYBOOK.md`** dans le skill gravedigger. 12 vecteurs complets.

- [ ] **State parameter** : absent ou prévisible ? → CSRF account takeover
- [ ] **redirect_uri** : manipulable ? (path traversal, subdomain, URL encoding) → token theft
- [ ] **PKCE** : requis sur les clients publics (SPA/mobile) ? S256 ou plain ? → code interception
- [ ] **Token type confusion** : access_token accepté comme id_token et vice-versa ?
- [ ] **Scope escalation** : peut-on demander des scopes non autorisés au refresh ?
- [ ] **Grant type** : implicit/password grants encore actifs ? (deprecated, high risk)
- [ ] **Code replay** : authorization code réutilisable ? (doit être single-use RFC 6749 §4.1.2)
- [ ] **Revocation** : token révoqué toujours accepté ? refresh_token non révoqué avec access_token ?
- [ ] **Wrapper vulns** : next-auth/passport/authlib/spring-oauth2 — vérifier CVEs connus pour la version
- [ ] **OIDC identity binding (V13)** : si "Sign in with Google/Microsoft/Apple" → décoder id_token JWT → l'app utilise `sub` (stable = SAFE) ou `email` (recyclable = ATO) comme identité ? Si email → account takeover via email recycling. 2 min. Ref: OpenID Connect Core §5.7, RFC 7519 §4.1.2. Priorité: healthcare/fintech/enterprise.

### F1.7 GraphQL (auto-activé si détecté)

```bash
# Détection GraphQL
for path in /graphql /graphiql /api/graphql /v1/graphql /graphql/playground; do
  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "${API}${path}" 2>/dev/null)
  [ "$code" != "000" ] && [ "$code" != "404" ] && echo "[GRAPHQL] $code $path"
done
GQL="${API}/graphql"

# Introspection — LE PREMIER TEST
SCHEMA=$(curl -s -X POST "$GQL" -H "Content-Type: application/json" \
  -d '{"query":"{ __schema { queryType { name } mutationType { name } types { name fields { name type { name } } } } }"}')
echo "$SCHEMA" | jq '.data.__schema.types[] | select(.fields != null) | {name, fields: [.fields[].name]}' 2>/dev/null
```

- [ ] **Introspection ouverte en prod** ? → schema complet = discovery de TOUTES les mutations admin
  ```bash
  # Extraire mutations (les plus dangereuses)
  echo "$SCHEMA" | jq -r '.data.__schema.mutationType.name as $mt | .data.__schema.types[] | select(.name == $mt) | .fields[].name' 2>/dev/null
  # Chaque mutation = un endpoint à tester sans auth
  ```
- [ ] **Batching attack** : bypass rate limiting via batch queries
  ```bash
  # 100 requêtes d'auth dans un seul POST
  curl -s -X POST "$GQL" -H "Content-Type: application/json" \
    -d '[{"query":"mutation{login(email:\"test@test.com\",pass:\"attempt1\"){token}}"},{"query":"mutation{login(email:\"test@test.com\",pass:\"attempt2\"){token}}"}]' | jq .
  # Si 200 pour toutes → pas de rate limiting par requête
  ```
- [ ] **Query depth DoS** : profondeur non limitée ?
  ```bash
  # Nested query depth bomb
  curl -s -X POST "$GQL" -H "Content-Type: application/json" \
    -d '{"query":"{ users { friends { friends { friends { friends { friends { id } } } } } } }"}' \
    -w "\nTime: %{time_total}s" | tail -5
  # Si réponse lente ou crash → DoS via query depth
  ```
- [ ] **Field-level auth** : les resolvers retournent-ils des champs non visibles dans l'UI ?
  ```bash
  # Query tous les champs d'un type, comparer à ce que l'UI montre
  curl -s -X POST "$GQL" -H "Content-Type: application/json" \
    -d '{"query":"{ me { id email role isAdmin internalId apiKey secretKey balance } }"}' \
    -H "Authorization: Bearer $TOKEN" | jq .
  ```
- [ ] **Mutation IDOR** : les mutations vérifient-elles l'ownership ?
  ```bash
  # Modifier la ressource d'un autre user
  curl -s -X POST "$GQL" -H "Content-Type: application/json" \
    -d '{"query":"mutation { updateProfile(userId: \"OTHER_USER_ID\", data: {role: \"admin\"}) { id role } }"}' \
    -H "Authorization: Bearer $MY_TOKEN" | jq .
  ```
- [ ] **Alias-based batching** : bypass de rate limiting via aliases GraphQL
  ```bash
  curl -s -X POST "$GQL" -H "Content-Type: application/json" \
    -d '{"query":"{ a1:login(pass:\"p1\"){t} a2:login(pass:\"p2\"){t} a3:login(pass:\"p3\"){t} }"}'
  ```

### F1.8 WebSocket (auto-activé si détecté)

```bash
# Détection WebSocket
for ws_path in /ws /socket /socket.io /graphql-ws /realtime /feed /stream /api/ws; do
  code=$(curl -s -o /dev/null -w "%{http_code}" "${API}${ws_path}" \
    -H "Upgrade: websocket" -H "Connection: Upgrade" -H "Sec-WebSocket-Version: 13" -H "Sec-WebSocket-Key: dGVzdA==" 2>/dev/null)
  [ "$code" = "101" ] && echo "[WS] UPGRADE $ws_path"
  [ "$code" = "200" ] && echo "[WS] OPEN $ws_path"
done
```

- [ ] **Auth sur WS upgrade** : le token est-il vérifié au moment de l'upgrade WS ?
  ```bash
  # Tenter connexion WS sans auth
  # wscat -c "wss://{domain}/ws" --no-check
  # Si connexion établie → CRITICAL: unauthenticated WS
  ```
- [ ] **CSWSH (Cross-Site WebSocket Hijacking)** : Origin validé sur le handshake ?
  ```bash
  curl -sI "${API}/ws" \
    -H "Upgrade: websocket" -H "Connection: Upgrade" \
    -H "Origin: https://evil.com" \
    -H "Sec-WebSocket-Version: 13" -H "Sec-WebSocket-Key: dGVzdA=="
  # Si 101 → CRITICAL: CSWSH possible
  ```
- [ ] **Messages WS sans re-auth** : les messages qui triggèrent des actions on-chain re-vérifient-ils l'auth ?
- [ ] **Rate limiting WS** : peut-on envoyer des milliers de messages sans throttling ?
- [ ] **WS → on-chain trigger** : un message WS peut-il déclencher une transaction sans vérification supplémentaire ?

### F1.9 Deserialization (grep patterns sur source et error messages)

```bash
# Détection dans les error messages
curl -s -X POST "${API}/endpoint" -H "Content-Type: application/json" -d 'invalid' 2>/dev/null | \
  grep -iP 'pickle|marshal|ObjectInputStream|Jackson|Fastjson|yaml\.load|unserialize|deserialize|fromJSON|node-serialize'

# Détection dans les headers
curl -sI "${API}/" | grep -iP 'x-powered-by|server' | grep -iP 'java|python|ruby|php'

# Si source disponible — grep pour patterns dangereux
# Python
grep -rn 'pickle\.loads\|yaml\.unsafe_load\|yaml\.load\b\|marshal\.loads\|shelve\.' --include="*.py" 2>/dev/null
# Java
grep -rn 'ObjectInputStream\|readObject\|enableDefaultTyping\|@JsonTypeInfo\|Fastjson\|JSONObject\.parse' --include="*.java" 2>/dev/null
# Node.js
grep -rn 'node-serialize\|unserialize\|eval(\|Function(\|serialize.*exec' --include="*.js" --include="*.ts" 2>/dev/null
# Ruby
grep -rn 'Marshal\.load\|YAML\.load\b\|Psych\.load\b' --include="*.rb" 2>/dev/null
# PHP
grep -rn 'unserialize\|__wakeup\|__destruct.*file\|phar://' --include="*.php" 2>/dev/null
```

- [ ] **Pickle/Marshal** dans les sessions ou caches Redis ?
- [ ] **Jackson enableDefaultTyping** dans les API Java ? (→ RCE si polymorphic deserialization)
- [ ] **yaml.load sans Loader** en Python ? (→ RCE via `!!python/object`)
- [ ] **Prototype pollution** via JSON.parse dans Node.js ?
- [ ] **Content-Type manipulation** : l'API accepte-t-elle `application/x-java-serialized-object` ou `application/x-yaml` ?

### F1.10 Authorization Consistency Matrix (MANDATORY — see gravedigger §4.12)

**C'est le test le plus souvent sauté et la source des findings les plus manqués.**

Un WAF qui retourne 403 = "requires auth", PAS "bloqué". L'API complète est accessible avec un token Bearer valide.

**Leçon apprise :** Request Finance — 103 routes extraites du bundle JS, dont `DELETE /users/mfa`. Toutes notées "high-value" mais JAMAIS testées avec authentification car le WAF retournait 403 sans auth. Un seul curl authentifié aurait révélé la suppression MFA sans re-auth (CVSS 7.6 HIGH).

```bash
TOKEN="<captured_bearer_token>"
API="https://{api_domain}"

# ÉTAPE 1: Acquérir un token via login normal
# DevTools → Network → API request → copier Authorization header

# ÉTAPE 2: Tester TOUTES les routes du bundle avec le token
for route in $(cat evidence/web/api-routes-extracted.txt); do
  code=$(curl -s -o /dev/null -w "%{http_code}" "${API}${route}" \
    -H "Authorization: Bearer $TOKEN" --max-time 10 2>/dev/null)
  [ "$code" != "000" ] && [ "$code" != "404" ] && echo "$code $route"
done

# ÉTAPE 3: Authorization Consistency Matrix
echo "=== OPS CRITIQUES (doivent requérir sudo/re-auth per OWASP ASVS V3.7.1) ==="
curl -s -o /dev/null -w "%{http_code} DELETE /users/mfa\n" \
  -X DELETE "${API}/users/mfa" -H "Authorization: Bearer $TOKEN"
curl -s -o /dev/null -w "%{http_code} DELETE /users/accounts/google\n" \
  -X DELETE "${API}/users/accounts/google" -H "Authorization: Bearer $TOKEN"
curl -s -o /dev/null -w "%{http_code} PATCH /users {email}\n" \
  -X PATCH "${API}/users" -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" -d '{"email":"test@evil.com"}'
curl -s -o /dev/null -w "%{http_code} PATCH /users {password}\n" \
  -X PATCH "${API}/users" -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" -d '{"password":"NewPass123"}'

echo "=== OPS NON-CRITIQUES (baseline de comparaison) ==="
curl -s -o /dev/null -w "%{http_code} GET /apps\n" \
  "${API}/apps" -H "Authorization: Bearer $TOKEN"
curl -s -o /dev/null -w "%{http_code} GET /users\n" \
  "${API}/users" -H "Authorization: Bearer $TOKEN"

# ÉTAPE 4: Test de suppression des notifications de sécurité
curl -s -X PATCH "${API}/users" -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"disabledEmails":["emailChangeConfirmation","emailChangeAlert"]}' | jq '.disabledEmails'
```

- [ ] **Session authentifiée acquise** — token Bearer capturé via login normal
- [ ] **TOUTES les routes du bundle testées avec token** — pas juste les routes unauth
- [ ] **Matrice de cohérence auth** : quelle opération requiert sudo vs token standard ?
- [ ] **Si une op LOW requiert plus d'auth qu'une op CRITICAL → finding HIGH (inconsistance prouvée)**
- [ ] **Suppression de notifications** : les alertes sécurité (`emailChange*`, `mfaDisabled`, `loginNewDevice`) sont-elles désactivables avec un token standard ?
- [ ] **Références** : OWASP ASVS V3.7.1, NIST SP 800-63B-4 §4.1.2.1, CWE-306
- [ ] **Précédents** : HackerOne #587910, #783258, #1139535, #2197244 ($1,000), CVE-2023-40260 (CVSS 9.1), CVE-2026-27946 (CVSS 8.2)

---

## F2. FRONTEND BUNDLE ANALYSIS (30 min)

### F2.1 JS Bundle Download & Secret Extraction

```bash
TARGET="https://{app_domain}"

# Télécharger tous les JS bundles
mkdir -p evidence/web/js-bundles
curl -s "${TARGET}" | grep -oE 'src="[^"]*\.js"' | sed 's/src="//;s/"//' | while read js; do
  curl -s "${TARGET}${js}" >> evidence/web/js-bundles/all-bundles.js
done

# Aussi télécharger les chunks dynamiques
curl -s "${TARGET}" | grep -oE '/_next/static/chunks/[^"]+\.js|/assets/[^"]+\.js' | while read js; do
  curl -s "${TARGET}${js}" >> evidence/web/js-bundles/all-bundles.js 2>/dev/null
done

SRC="evidence/web/js-bundles/all-bundles.js"
echo "Bundle size: $(wc -c < $SRC) bytes"

# === CRITICAL: Credentials ===
grep -oEi '(master.?password|admin.?password|secret.?key|private.?key)\s*[:=]\s*["\x27][^"\x27]+' "$SRC"
grep -oEi 'password\s*[:=]\s*["\x27][^"\x27]{8,}' "$SRC"

# === HIGH: API Keys ===
grep -oEi 'AKIA[0-9A-Z]{16}' "$SRC"                              # AWS
grep -oEi 'sk[-_]live[-_][a-zA-Z0-9]{20,}' "$SRC"                 # Stripe secret
grep -oEi 'ghp_[a-zA-Z0-9]{36}' "$SRC"                            # GitHub PAT
grep -oEi 'xox[bpras]-[a-zA-Z0-9-]+' "$SRC"                       # Slack
grep -oEi 'hooks\.slack\.com/services/T[A-Z0-9]+/B[A-Z0-9]+/[a-zA-Z0-9]+' "$SRC"  # Slack webhook
grep -oEi 'CG-[a-zA-Z0-9]{20,}' "$SRC"                            # CoinGecko
grep -oEi '[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}' "$SRC" | head -20  # UUIDs (API keys, project IDs)

# === MEDIUM: Configuration ===
grep -oEi 'VITE_APP_[A-Z_]+\s*[:=]' "$SRC"                        # Vite env vars
grep -oEi 'NEXT_PUBLIC_[A-Z_]+' "$SRC"                             # Next.js env vars
grep -oEi 'REACT_APP_[A-Z_]+' "$SRC"                               # CRA env vars
grep -oEi '(sentry|dsn|raven).*https?://[^"]+' "$SRC"              # Sentry DSN
grep -oEi 'https?://[a-z0-9-]+\.execute-api\.[a-z0-9-]+\.amazonaws\.com' "$SRC"  # Lambda
grep -oEi 'wss?://[^"]+' "$SRC"                                    # WebSocket endpoints
grep -oEi 'https?://[a-z0-9-]+\.(alchemy|infura|quicknode|ankr)\.(com|io)/[^"]+' "$SRC"  # RPC URLs with keys

# === INFO: Architecture ===
grep -oEi 'backend[-_]?(dev|staging|qa|test|internal)\.[a-z]+\.[a-z]+' "$SRC"  # Backend hostnames
grep -oEi '(fireblocks|turnkey|fordefi|copper|cobo|dfns)\b' "$SRC"   # Custodian
grep -oEi '(alchemy|infura|quicknode|moralis|ankr|goldsky|thegraph)\b' "$SRC"  # Infra providers
```

- [ ] **Master password / credentials** dans le bundle = CRITICAL (like Upshift W34)
- [ ] **API keys actives** dans le bundle = HIGH (like Upshift W27)
- [ ] **Slack webhooks** dans le bundle = MEDIUM
- [ ] **Sentry DSN** exposé = MEDIUM (wallet-to-IP correlation, like Upshift W30)
- [ ] **Lambda/serverless URLs** dans le bundle = test sans auth immédiatement
- [ ] **Backend hostnames staging/dev** dans le bundle = tester immédiatement
- [ ] **Custodian identifié** (Fireblocks, Turnkey, Copper, etc.) = noter pour key arch analysis

### F2.2 Legacy Frontend Discovery

```bash
# Vérifier si d'anciennes versions du frontend sont encore en ligne
# Rebranding = ancien domaine souvent encore live avec anciennes configs

for legacy in "app.{old_domain}" "v1.{domain}" "v2.{domain}" "legacy.{domain}" "old.{domain}" "{old_name}.{tld}"; do
  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "https://${legacy}/" 2>/dev/null)
  [ "$code" != "000" ] && [ "$code" != "404" ] && echo "[LEGACY] $code https://${legacy}/"
done

# Si legacy frontend trouvé :
# 1. Télécharger les bundles JS séparément
# 2. Scanner pour des secrets qui ne sont PLUS dans la version actuelle
# 3. Vérifier si le legacy frontend parle au MEME backend que le prod actuel
```

- [ ] **Legacy frontend** encore live ? (like Upshift V2 sur augustdigital.io)
- [ ] **Legacy contient des secrets** absents de la version actuelle ? = CRITICAL
- [ ] **Legacy sans WAF** alors que le prod en a un ? = surface d'attaque élargie
- [ ] **Legacy backend identique** au prod ? (tester mêmes endpoints)

### F2.3 Source Maps

```bash
# Chercher les source maps exposées
for chunk in $(curl -s "${TARGET}" | grep -oE '/[^"]+\.js' | head -30); do
  map_code=$(curl -s -o /dev/null -w "%{http_code}" "${TARGET}${chunk}.map" 2>/dev/null)
  [ "$map_code" = "200" ] && echo "[SOURCEMAP] ${chunk}.map"
done
```

- [ ] **Source maps accessibles** = toute la logique serveur/client exposée

### F2.4 Supply Chain Dependency Audit (NEW)

#### F2.4.1 Dependency Tree Extraction

```bash
TARGET_REPO="path/to/cloned/repo"

# NPM
cat "${TARGET_REPO}/package-lock.json" | jq '.dependencies | keys | length'
cat "${TARGET_REPO}/package-lock.json" | jq '.dependencies | to_entries[] | select(.value.resolved | test("github|gitlab|bitbucket")) | .key'
cd "${TARGET_REPO}" && npm ls --all --json 2>/dev/null | jq '[.. | .name? // empty] | unique | length'

# Python
pip-audit --format json 2>/dev/null | jq 'length'

# Rust
cd "${TARGET_REPO}" && cargo tree --depth 1 2>/dev/null | wc -l

# From frontend bundles (if no repo access)
grep -oE 'node_modules/([^/]+)/' evidence/web/js-bundles/all-bundles.js | sort -u
```

- [ ] **Total dependency count** documented (direct + transitive)
- [ ] **Non-registry dependencies** flagged (GitHub URLs, local paths = unvetted sources)
- [ ] **>500 transitive deps** in a DeFi protocol = red flag

#### F2.4.2 Malicious Package Signal Detection

```bash
# postinstall script analysis
cd "${TARGET_REPO}" && cat package-lock.json | \
  jq -r '.dependencies | to_entries[] | select(.value.hasInstallScript == true) | .key'

# Crypto-specific malicious patterns
grep -rn "ethers.*Wallet\|web3.*accounts\|@solana/web3.js.*Keypair" node_modules/ --include="*.js" | head -20
grep -rn "mnemonic\|seed.phrase\|private.key\|keystore" node_modules/ --include="*.js" | grep -v "test\|example\|readme" | head -20
grep -rn "\.ethereum\|\.solana\|wallet\.dat" node_modules/ --include="*.js" | head -20
grep -rn "eval(\|Function(" node_modules/ --include="*.js" | grep -v "test\|webpack\|babel" | head -20
grep -rn "process\.env\." node_modules/ --include="*.js" | grep -iE "key|secret|token|password|private|mnemonic" | head -20
grep -rn "\\\\x[0-9a-f]{2}\\\\x[0-9a-f]{2}" node_modules/ --include="*.js" | head -10
```

- [ ] **Packages with install scripts** listed and inspected
- [ ] **No wallet/key access** in non-crypto dependencies
- [ ] **No exfiltration patterns** (outbound network to unknown endpoints)
- [ ] **No obfuscated code** in dependencies that shouldn't need it
- [ ] **No eval/dynamic execution** in non-build dependencies

#### F2.4.3 Typosquat & Maintainer Analysis

```bash
DEPS=$(cat package-lock.json | jq -r '.dependencies | keys[]')

# Known typosquats
for typo in "colours" "chalkjs" "lodas" "expresss" "axois" "ethersjs" "web3js" "solana-web3" "hardhat-core"; do
  echo "$DEPS" | grep -ix "$typo" && echo "[TYPOSQUAT] Found: $typo"
done

# Maintainer change on critical packages
for pkg in $(echo "$DEPS" | grep -iE "jwt|auth|crypto|wallet|sign|key|token|web3|ethers|solana"); do
  npm view "${pkg}" maintainers time --json 2>/dev/null | jq '{maintainers, modified: .time.modified}'
done
```

- [ ] **No typosquats** in dependency tree
- [ ] **Critical package maintainers** stable (no recent changes on auth/crypto packages)
- [ ] **New packages** (<6 months) in security-critical paths flagged

#### F2.4.4 Known Vulnerability Baseline

```bash
# NPM
npm audit --json 2>/dev/null | jq '{critical: .metadata.vulnerabilities.critical, high: .metadata.vulnerabilities.high}'
# Python
pip-audit --format json 2>/dev/null | jq 'length'
# Rust
cargo audit --json 2>/dev/null | jq '.vulnerabilities.found'
```

- [ ] **Zero critical/high CVEs** — or documented and assessed
- [ ] **Unmaintained packages** in critical paths flagged (like python-jose)
- [ ] **Ref**: Bybit ($1.4B) Safe{Wallet} supply chain, npm chalk/debug Sep 2025, event-stream 2018

---

## F3. INFRASTRUCTURE & DNS (20 min)

### F3.1 DNSSEC & DNS Security

```bash
# Vérifier DNSSEC sur chaque domaine
for domain in "{domain}" "{legacy_domain}" "{staging_domain}"; do
  dig +dnssec "${domain}" | grep -q "RRSIG" && echo "[OK] DNSSEC: ${domain}" || echo "[VULN] NO DNSSEC: ${domain}"
done

# Vérifier les enregistrements DNS
dig ANY "{domain}"
dig TXT "{domain}"   # SPF, DMARC, verification records
dig MX "{domain}"    # Email provider
```

- [ ] **DNSSEC activé** sur TOUS les domaines ? (sinon → DNS hijacking, like Curve $3.5M, Aerodrome $700K)
- [ ] **Registrar lock** activé ?
- [ ] **Plusieurs domaines** = plusieurs surfaces DNS

### F3.2 WAF & CDN Detection

```bash
# Par domaine — tester la présence de WAF
for domain in "{app_domain}" "{api_domain}" "{legacy_domain}" "{staging_domain}"; do
  headers=$(curl -sI "https://${domain}/" 2>/dev/null)
  echo "=== ${domain} ==="
  echo "$headers" | grep -iE 'cf-ray|x-vercel|x-amz|x-cloud|server:|x-waf|x-shield'
  echo "$headers" | grep -iE 'set-cookie.*__cf\|__vercel\|AWSALB'
done
```

- [ ] **WAF par domaine** documenté (Cloudflare, Vercel, AWS WAF, none)
- [ ] **Domaine sans WAF** servant des données sensibles ? = surface d'attaque
- [ ] **Staging sans WAF** mais avec données prod ? (like Upshift W32)

### F3.3 Debug & Internal Endpoints

```bash
API="https://{api_domain}"

for path in /health /healthz /ping /status /info /version /env /config /threads /sentry-debug /debug /debug/vars /debug/pprof /metrics /prometheus /actuator /actuator/health /actuator/env /_internal /server-status /server-info /graphql; do
  resp=$(curl -s -w "\n%{http_code}" --max-time 5 "${API}${path}" 2>/dev/null)
  code=$(echo "$resp" | tail -1)
  [ "$code" != "000" ] && [ "$code" != "404" ] && [ "$code" != "405" ] && echo "[DEBUG] $code $path"
done

# Staging backend (si trouvé en F0.3)
STAGING="https://{staging_domain}"
for path in /health /threads /sentry-debug /openapi.json; do
  resp=$(curl -s -w "\n%{http_code}" --max-time 5 "${STAGING}${path}" 2>/dev/null)
  code=$(echo "$resp" | tail -1)
  [ "$code" != "000" ] && [ "$code" != "404" ] && echo "[STAGING-DEBUG] $code $path"
done
```

- [ ] **/health** expose des détails infra ? (RPC URLs, latences, DB status, like Upshift W12)
- [ ] **/threads** expose la stack interne ? (like Upshift W11)
- [ ] **/sentry-debug** trigger de vraies exceptions ? (like Upshift W11)
- [ ] **Staging endpoints** accessibles publiquement ? (like Upshift W32)
- [ ] **Staging = replica prod** ? (comparer nonces/données entre staging et prod)

### F3.4 RPC Node Exposure (NEW)

```bash
# Discover protocol-operated RPC endpoints from bundles
grep -oEi 'https?://[a-z0-9.-]+\.(rpc|node|chain|web3)\.[a-z]+[^"]*' evidence/web/js-bundles/all-bundles.js
grep -oEi 'wss?://[^"]+' evidence/web/js-bundles/all-bundles.js
curl -s "${API}/health" 2>/dev/null | grep -oEi 'https?://[a-z0-9.-]+(rpc|node|web3)[^"]*'

# For each discovered RPC endpoint:
RPC_URL="https://discovered-rpc"

# Should work (public node)
curl -s -X POST "${RPC_URL}" -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","id":1}'

# Should NOT work — private mempool leak
curl -s -X POST "${RPC_URL}" -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"txpool_content","id":1}'

# CRITICAL — admin/personal namespace
curl -s -X POST "${RPC_URL}" -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"admin_peers","id":1}'
curl -s -X POST "${RPC_URL}" -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"personal_listAccounts","id":1}'

# Debug namespace
curl -s -X POST "${RPC_URL}" -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"debug_traceTransaction","params":["0x0000000000000000000000000000000000000000000000000000000000000000"],"id":1}'

# Rate limiting
for i in $(seq 1 50); do
  curl -s -o /dev/null -w "%{http_code}" -X POST "${RPC_URL}" \
    -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"eth_blockNumber","id":1}'
done | sort | uniq -c
```

- [ ] **Protocol-operated RPC endpoints** discovered and listed
- [ ] **txpool namespace** NOT exposed (exposed = mempool leak → MEV)
- [ ] **debug namespace** NOT exposed (exposed = state extraction)
- [ ] **admin/personal namespace** NOT exposed (CRITICAL — node takeover/wallet access)
- [ ] **Rate limiting** present on all RPC endpoints

### F3.5 Keeper / Bot Infrastructure (NEW)

```bash
# Identify keeper wallets from contract events
# who calls: harvest(), rebalance(), liquidate(), updatePrice(), execute()
# Caller address = keeper wallet

# From frontend bundles / config endpoints
grep -oEi '0x[a-fA-F0-9]{40}' evidence/web/js-bundles/all-bundles.js | sort -u
curl -s "${API}/configs" 2>/dev/null | grep -oEi '0x[a-fA-F0-9]{40}' | sort -u

# For each identified keeper:
KEEPER="0x..."
cast balance ${KEEPER} --rpc-url ${RPC}
# Unlimited approvals?
cast call <TOKEN> "allowance(address,address)(uint256)" ${KEEPER} <PROTOCOL_CONTRACT> --rpc-url ${RPC}
# Multi-chain presence?
for rpc in "https://ethereum-rpc.publicnode.com" "https://arbitrum-one-rpc.publicnode.com" "https://base-rpc.publicnode.com"; do
  echo "${rpc}: $(cast balance ${KEEPER} --rpc-url ${rpc} 2>/dev/null)"
done
```

- [ ] **Keeper wallets identified** with role and chain presence
- [ ] **Keeper balances** — excess funds beyond gas needs?
- [ ] **Keeper approvals** — unlimited approvals to any contract? (compromised key = instant drain)
- [ ] **Keeper key type** — EOA (hot wallet risk) or contract?
- [ ] **Same key on all chains** = single compromise = multi-chain impact

### F3.6 Off-Chain Metadata & IPFS Integrity (NEW)

```bash
# Governance proposals — off-chain metadata manipulation
grep -rn "proposalURI\|descriptionHash\|ipfs\|arweave\|metadataURI" --include="*.sol"

# NFT / Token metadata
grep -rn "tokenURI\|baseURI\|contractURI" --include="*.sol"
TOKEN_URI=$(cast call ${CONTRACT} "tokenURI(uint256)(string)" 1 --rpc-url ${RPC} 2>/dev/null)
echo "Token URI: ${TOKEN_URI}"
# HTTP = mutable (admin/DNS compromise = substitution). ipfs:// = immutable

# Frontend config on IPFS/Arweave
grep -oEi 'ipfs://[a-zA-Z0-9]+|Qm[a-zA-Z0-9]{44}|bafy[a-zA-Z0-9]+' evidence/web/js-bundles/all-bundles.js
```

- [ ] **Governance metadata** — mutable or immutable? Admin-changeable?
- [ ] **Token metadata** — HTTP (mutable) or IPFS (immutable)?
- [ ] **baseURI admin changeable** without timelock = metadata substitution risk
- [ ] **Single IPFS pinning entity** — if goes down, protocol breaks?

---

## F4. SIGNING & KEY ARCHITECTURE (30 min)

**Le finding le plus impactant d'Upshift (W35) venait de cette section. Ne JAMAIS la skipper.**

### F4.1 Proxy Governance Chain Tracer (EXPANDED)

```bash
# For EACH proxy contract in scope — resolve FULL governance chain

PROXY="0x..."
RPC="https://ethereum-rpc.publicnode.com"

# Step 1: Read EIP-1967 slots
IMPL=$(cast storage ${PROXY} 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url ${RPC})
ADMIN=$(cast storage ${PROXY} 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103 --rpc-url ${RPC})

# Step 2: Classify admin
ADMIN_CODE=$(cast code ${ADMIN} --rpc-url ${RPC})
if [ "${ADMIN_CODE}" = "0x" ]; then
  echo "[CRITICAL] Admin is EOA — single key controls upgrades"
fi

# Step 3: Resolve chain — Safe? Timelock? ProxyAdmin?
THRESHOLD=$(cast call ${ADMIN} "getThreshold()(uint256)" --rpc-url ${RPC} 2>/dev/null)
DELAY=$(cast call ${ADMIN} "getMinDelay()(uint256)" --rpc-url ${RPC} 2>/dev/null)
PA_OWNER=$(cast call ${ADMIN} "owner()(address)" --rpc-url ${RPC} 2>/dev/null)

# Step 4: Implementation initialization check
INITIALIZED=$(cast storage ${IMPL} 0x0 --rpc-url ${RPC})

# Step 5: Beacon proxy check
BEACON=$(cast storage ${PROXY} 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50 --rpc-url ${RPC})

# MCP tools:
# evm_resolve_proxy(address, chain)
# evm_call(to=admin_address, data="0x8da5cb5b", chain)  # owner()
# evm_get_bytecode(address, chain)  # 0 bytes = EOA
```

**Chain resolution (recurse until EOA or max depth 6):**
```
Level 0: Implementation (0x...)    → _initialized? _disableInitializers()?
Level 1: Proxy (0x...)             → Type: Transparent/UUPS/Beacon → Admin
Level 2: ProxyAdmin (0x...)        → owner() → Level 3
Level 3: Timelock (0x... or ABSENT) → delay, proposers, executors
Level 4: Safe/Multisig (0x...)     → threshold X-of-Y, owners
Level 5: Governance (if any)       → quorum, token concentration
```

**Severity per weakness:**

| Weakness | Severity |
|----------|----------|
| Admin is EOA | CRITICAL |
| Safe threshold 1-of-N | HIGH |
| No timelock | HIGH |
| Timelock < 24h | MEDIUM |
| Implementation uninitialized | HIGH |
| Same admin key across all chains | HIGH |
| Beacon proxy (1 upgrade = ALL proxies) | HIGH |

- [ ] **Full chain resolved** for every proxy: Ultimate Controller → [Timelock?] → [Safe?] → [ProxyAdmin?] → Proxy → Implementation
- [ ] **Weakest link** identified with severity
- [ ] **Implementation initialized** — `_disableInitializers()` called?
- [ ] **Upgrade history** — when was the last upgrade? By whom?
- [ ] **Cross-chain consistency** — same admin architecture on ALL chains?
- [ ] **Beacon proxy** — compromising beacon upgrades ALL proxies simultaneously?
- [ ] **Emergency bypass** — timelock has emergency executor without delay?
- [ ] **Ref**: Bybit ($1.4B) — Safe{Wallet} UI → proxy upgrade. zkSync ($5M) — admin key sweepUnclaimed(). CPIMP 2025 — proxy init front-running

### F4.2 Vault/Protocol Owner Architecture

```bash
# Pour chaque vault ou contrat principal :
# Vérifier owner(), admin(), governance(), guardian()

# MCP tools:
# evm_call(to=vault, data="0x8da5cb5b")  # owner()
# evm_call(to=safe_addr, data="0xe75235b8")  # getThreshold()
# evm_call(to=safe_addr, data="0xa0e67e2b")  # getOwners()
```

- [ ] **Tous les vaults** utilisent multisig pour owner ? Lister les exceptions
- [ ] **Threshold >= 2** sur toutes les Safes ? (1-of-N = FINDING, like Upshift W39)
- [ ] **Cohérence** entre vaults : mêmes seuils partout ? Les outliers sont des findings
- [ ] **Emergency functions** protégées par timelock ? (`emergencyWithdraw`, `pause`, `kill`)

### F4.3 Operator / Executor Key Mapping

```bash
# Identifier TOUTES les clés de signing du protocole :
# - Operator (daily operations)
# - Executor (transaction submission)
# - Deployer (initial deployment, may retain admin)
# - MPC/Custodian keys (Fireblocks, Turnkey, Copper)

# Sources :
# 1. Config endpoints sans auth (like Upshift /configs/*)
# 2. On-chain: who calls the contracts? (check recent txs)
# 3. Frontend bundles: operator addresses hardcoded

# Pour chaque clé trouvée :
# - Est-ce un EOA ou un contrat ?
# - Quel est son solde gas ? (budget pour drain attempt)
# - Sur combien de chains est-elle active ?
# - Quelles fonctions peut-elle appeler ?
```

- [ ] **Clés de signing listées** avec type (EOA/Safe/MPC) et rôle
- [ ] **Single key** contrôle les opérations sur TOUTES les chains ? = HIGH (like Upshift W23)
- [ ] **Operator = EOA** sans multisig ? = peut être drainé de son gas (like Upshift W20)
- [ ] **Config endpoints** exposent les adresses des clés sans auth ? (like Upshift W23)
- [ ] **Trail of Bits Maturity Level** identifié : Level 1 (EOA) / Level 2 (multisig) / Level 3 (timelock + roles) / Level 4 (immutable)

### F4.4 Custodian / MPC Integration

```bash
# Si le protocole utilise un custodian (Fireblocks, Turnkey, Copper, ForDefi) :
# - Le custodian est-il le seul gate avant l'exécution on-chain ?
# - Le custodian peut-il être contourné via l'API du protocole ?
# - Les credentials du custodian sont-elles exposées (frontend, config endpoints) ?

# Grep dans les bundles JS :
grep -iE '(fireblocks|turnkey|fordefi|copper|dfns|cobo)' evidence/web/js-bundles/all-bundles.js
```

- [ ] **Custodian identifié** et son rôle dans la chaîne de signing documenté
- [ ] **Custodian bypassable** via l'API du protocole ? (W34 + W1 d'Upshift bypasse Fireblocks)
- [ ] **Credentials custodian** exposées dans frontend/API ?

---

## F5. SMART CONTRACT ARCHITECTURE (60 min)

### F5.1 ERC-4626 Vault Protection

```bash
# Si le protocole utilise des vaults ERC-4626 :

# Vérifier la protection inflation
# evm_call(to=vault, data=encode("previewDeposit(uint256)", 1))  # 0 = pas de virtual offset
# evm_call(to=vault, data=encode("convertToShares(uint256)", 1e18))  # Linear = pas de dead shares

# Chercher _decimalsOffset dans le bytecode
# evm_get_bytecode(vault) -> grep pour le pattern
```

- [ ] **Virtual shares / _decimalsOffset** présent ? (absent = inflation attack possible, like Upshift W38)
- [ ] **Dead shares** implémenté ? (première mint vers address(0))
- [ ] **Nombre de vaults** × **nombre de chains** = surface de risque
- [ ] **Nouveaux vaults** déployés récemment ? (fenêtre de vulnérabilité)
- [ ] **Référence** : Resupply $9.5M (Jun 2025) — donation attack sur vault de 1.5h

### F5.2 Event Coverage

```bash
# Pour chaque fonction state-changing critique, vérifier qu'un event est émis
# Les fonctions SANS events = opérations silencieuses = monitoring aveugle

# Fonctions critiques à vérifier :
# - deposit/withdraw/transfer (mouvements de fonds)
# - setOperator/setAdmin/transferOwnership (changements de contrôle)
# - emergencyWithdraw/pause/unpause (opérations d'urgence)
# - updateTotalAssets/collectFees (changements comptables)
# - addToBlacklist/removeFromBlacklist (restrictions utilisateur)

# Vérifier dans le bytecode ou le source vérifié :
# grep -n "emit " Contract.sol | wc -l  # Nombre d'events émis
# grep -n "function " Contract.sol | grep -v "view\|pure" | wc -l  # Nombre de fonctions state-changing
```

- [ ] **Toutes les fonctions de mouvement de fonds** émettent des events ?
- [ ] **Fonctions admin** émettent des events ?
- [ ] **Si events manquants** = drainage silencieuse possible (like Upshift W40 — 11 fonctions muettes)

### F5.3 Pipeline 2025-2026 Checks

**Exécuter les sections 6b.1-6b.9 du `CRITICAL-HUNT-CHECKLIST.md` :**

- [ ] **6b.1 EIP-7702** : `grep tx.origin` dans bytecode/source → si présent, tx.origin bypass post-Pectra
- [ ] **6b.2 V4 Hooks** : protocole utilise des hooks Uniswap V4 ? → section dédiée
- [ ] **6b.3 Transient Storage** : `TSTORE/TLOAD` dans bytecode → slot aliasing risk
- [ ] **6b.4 CPIMP** : proxy `_initialized` vérifié sur TOUTES les chains → front-run risk
- [ ] **6b.5 Perp DEX Oracle** : si perp → oracle-liquidity manipulation
- [ ] **6b.6 Supply Chain UI** : signing via web UI → Bybit pattern
- [ ] **6b.7 Groth16** : si ZK → delta2 == gamma2 check
- [ ] **6b.8 ERC-4626 Inflation** : couvert dans F5.1
- [ ] **6b.9 Deflationary Tokens** : vaults acceptent des tokens fee-on-transfer ?
- [ ] **6b.10-12 JWT/Auth** : JWT detected? → JWT Arsenal auto-activated (§F1.4)
- [ ] **§3.6 Mirror Invariant Audit (MANDATORY — CLAUDE.md rule #41)** : pour chaque paire in/out (transferToAgent/transferToken, lock/unlock, mint/burn, deposit/withdraw, encode/decode), extraire V_in vs V_out côte à côte. Toute asymétrie sans raison articulable = finding-candidate. Voir `CRITICAL-HUNT-CHECKLIST.md §3.6` pour les tables et les grep patterns. **Gate mécanique** : aucun fichier in/out ne doit être noté "audited clean" sans la ligne de comparaison miroir explicite dans les notes.
- [ ] **6b.13 Supply Chain** : dependencies audited (§F2.4)
- [ ] **6b.14 ERC-4337 AA** : `grep IEntryPoint\|UserOperation\|IPaymaster` → if detected, paymaster sig binding, postOp reentrancy, factory front-running, module installation. See `ZERO-DAY-METHODOLOGY.md` D3

### F5.4 Balance Check & Token Handling

```bash
# Vérifier si le protocole utilise balanceOf(this) ou un tracking interne
# balanceOf(this) = manipulable par donation
# Si balance checks retirées (comme Upshift, audit CS-AUGCORE-003) → documenter

# Lister les tokens acceptés par les vaults
# Pour chaque token exotique : vérifier fee-on-transfer, pausability, blacklist
```

- [ ] **Balance checks** : `balanceOf(this)` vs accounting interne ?
- [ ] **Tokens exotiques** dans les vaults vérifiés pour fee-on-transfer ?
- [ ] **Balance post-condition checks** présentes ? (retirées dans Upshift)

---

## F6. ATTACK CHAIN CONSTRUCTION (30 min)

### F6.1 Cross-Reference Matrix

**Après avoir complété F1-F5, croiser TOUS les findings :**

```
Pour chaque paire de findings (A, B) :
  - A fournit-il un prerequisite pour B ?
  - A + B ont-ils un impact combiné supérieur à A + B isolés ?
  - A ouvre-t-il un chemin vers B qui n'existait pas ?

Patterns de chaîne classiques :
  Info Leak → Auth Bypass → Fund Drain
  Config Endpoint → Key Discovery → On-Chain Abuse
  Legacy Frontend → Credential Extraction → API Takeover
  Unauth Endpoint → On-Chain Trigger → Gas Drain / Role Expansion
  DNSSEC Absent → DNS Hijack → Phishing + API Credential Theft
```

- [ ] **Matrice N×N** construite pour tous les findings
- [ ] **Chaînes d'attaque** identifiées et documentées
- [ ] **Coût d'attaque** calculé pour chaque chaîne ($0 = le plus impactant)
- [ ] **Chemins indépendants** identifiés (si chemin 1 est bloqué, chemin 2 existe ?)

### F6.2 Fund Theft Path Validation

```
Pour chaque chemin de fund theft identifié, valider :
1. ACCESS : Comment l'attaquant obtient-il l'accès initial ?
   - Credential dans bundle (W34 pattern)
   - Endpoint sans auth (W1 pattern)
   - Key compromise (W35 pattern)
   - DNS hijack (W36 pattern)

2. EXECUTION : Comment les fonds sont-ils drainés ?
   - Via API (tx_batcher, swap, withdraw endpoints)
   - Via on-chain (proxy upgrade, direct contract call)
   - Via social (phishing signatures)

3. DETECTION : Le drain sera-t-il détecté ?
   - Events émis ? (W40 : non)
   - Monitoring actif ? (Forta, Defender)
   - Timelock avant exécution ? (W35 : non)

4. RECOVERY : Le protocole peut-il récupérer les fonds ?
   - Pause mechanism exists ?
   - Funds are bridgeable to unrecoverable chains ?
   - Timelock allows intervention ?
```

- [ ] **Chemin complet** documenté avec prérequis, exécution, détection, recovery
- [ ] **Calldata proof** si possible (like Upshift — HTTP 200 avec calldata Aave)
- [ ] **TVL par chemin** calculé

### F6.3 Dismissal Vector Pre-Analysis

```
Pour chaque finding/chaîne, préparer les contre-arguments :

Dismissal attendu                     | Contre-argument
"Le custodian bloque"                 | Chemin X bypasse le custodian (comment)
"C'est un risque connu/accepté"       | L'audit date de Y, Z vaults ajoutés depuis, scale change le risque
"L'admin peut intervenir"             | Pas de timelock (W35), opérations silencieuses (W40)
"C'est pas réaliste"                  | Bybit $1.4B = même architecture mais PLUS sécurisée
"On va le corriger"                   | Le legacy frontend (W34) est live depuis X mois
"C'est hors scope"                    | $332M TVL, code déployé, users à risque
```

- [ ] **Chaque dismissal** anticipé avec un contre-argument factuel
- [ ] **Précédents 2025-2026** cités pour chaque pattern

### F6.4 Attack Chain Composition

**Trigger:** 2+ findings exist on the same target after F1-F6.3 complete.

Run `ATTACK-CHAIN-PLAYBOOK.md` (in gravedigger skill) to compose individual findings into multi-step attack chains before Kill Gate. Finding A enabling finding B produces combined severity greater than the sum of parts.

- [ ] **All finding pairs** evaluated for causal dependency (A enables B)
- [ ] **Attack graphs** built (entry → pivot → impact) with combined severity
- [ ] **Chain-specific PoCs** demonstrate full multi-step path
- [ ] **Dismissal counters** pre-built for "these are separate issues" responses

**Ref:** `~/.claude/skills/gravedigger/ATTACK-CHAIN-PLAYBOOK.md`

---

## F7. WORKFLOW COMPLET

```
Pour chaque target DeFi full-stack :

1. RECON (30 min)            → F0 : TVL, tech stack, domaines, audits
2. API SURFACE (60 min)      → F1 : OpenAPI, auth classification, unauth writes
3. FRONTEND BUNDLES (30 min) → F2 : Secrets, legacy, source maps, supply chain audit (F2.4 NEW)
4. INFRASTRUCTURE (30 min)   → F3 : DNSSEC, WAF, debug, RPC exposure (F3.4), keepers (F3.5), metadata (F3.6)
5. KEY ARCHITECTURE (30 min) → F4 : Proxy admin, vault owners, operator keys, custodian
6. SMART CONTRACTS (60 min)  → F5 : ERC-4626, events, pipeline 2025-2026
                                → CRITICAL-HUNT-CHECKLIST.md (si DeFi)
                                → SOLANA-HUNT-CHECKLIST.md (si Solana)
                                → NEXTJS-HUNT-CHECKLIST.md (si Next.js)
7. ATTACK CHAINS (30 min)    → F6 : Cross-reference, fund theft validation
7b. CHAIN COMPOSITION         → F6.4 : ATTACK-CHAIN-PLAYBOOK.md (if 2+ findings)
8. KILL GATE (30 min/finding) → KILL-GATE-TEMPLATE.md
9. PREFLIGHT (15 min/finding) → PREFLIGHT-CHECK.md (min 22/24)
10. DISCLOSE                  → /disclose

Total : 5-6h pour le scan initial
      + 3h/finding pour deep dive + PoC
      + 15-25h total max par target
```

**Priority order (highest ROI first) :**
1. F2.1 (frontend bundles) — 5 min de travail peut donner un fund theft (like Upshift W34)
2. F1.3 (unauth write endpoints) — chaque endpoint POST sans auth est potentiellement CRITICAL
3. F4.1 (proxy admin) — une vérification on-chain peut révéler un SPOF à $XxxM
4. F2.2 (legacy frontend) — les rebrands laissent souvent des cadavres
5. F3.3 (staging backends) — staging = prod data sans protection
6. F1.4 (auth deep testing) — SIWE broken = replay permanent

---

## F8. REFERENCES

| Date | Protocole | Montant | Vecteur Full-Stack | Sections Applicables |
|------|-----------|---------|-------------------|---------------------|
| 2026 | **Upshift** | $332M at risk | Master password in legacy JS + unauth on-chain trigger | F2.1, F1.3, F4.1 |
| Feb 2025 | **Bybit** | $1.4B | Safe{Wallet} UI supply chain → proxy upgrade | F4.1, F4.4 |
| Nov 2025 | **Aerodrome** | $700K | DNS hijack via registrar compromise | F3.1 |
| May 2025 | **Curve** | $3.5M | DNS hijack at registrar level | F3.1 |
| Jun 2025 | **Resupply** | $9.5M | ERC-4626 donation attack on fresh vault | F5.1 |
| Jan 2026 | **Matcha** | $13.5M | Open allowances + arbitrary call | F1.3, F5.4 |
| Sep 2025 | **npm chalk/debug** | supply chain | Crypto-drainer in dependency | F2.1 |
| Feb 2026 | **CrossCurve** | $3M | Axelar expressExecute message spoofing | F5.3 (cross-chain) |
| Feb 2026 | **IoTeX Bridge** | $4.3M | Validator key compromise + malicious upgrade | F4.1 |
| Apr 2025 | **zkSync** | $5M | Admin key sweepUnclaimed() on airdrop | F4.1 |
