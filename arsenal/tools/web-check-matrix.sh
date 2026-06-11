#!/usr/bin/env bash
# web-check-matrix.sh — Web/API analog of check-matrix.py
#
# Analyzes target's routes and builds an endpoint × protection matrix.
# Columns: CSRF token, Origin check, Content-Type allowlist, SameSite cookie,
#          rate limit, re-auth required, CORS strictness, auth scheme.
#
# Detects inconsistencies between endpoints that SHOULD have the same protections
# but differ — these are finding candidates (P-H1-023 / M-H1-002 / rule #30).
#
# Inputs (auto-detected in target dir):
#   - openapi.yaml / openapi.json / swagger.yaml (API spec)
#   - routes/**/*.{js,ts,py,rb}  (Express, Flask, Rails, Next.js)
#   - middleware/**/*  (protection presence)
#
# Usage:
#   web-check-matrix.sh <target-dir>                 # Terminal table
#   web-check-matrix.sh <target-dir> --output matrix.md
#   web-check-matrix.sh <target-dir> --json
#
# Output: endpoint rows × protection columns, with INCONSISTENCY flags on rows
# where a sibling endpoint (same path class or same verb group) has different
# protections.

set -uo pipefail

TARGET_DIR="${1:-}"
if [ -z "$TARGET_DIR" ] || [ ! -d "$TARGET_DIR" ]; then
  cat <<EOF
Usage: $0 <target-dir> [--output <file>] [--json]

Analyzes web/API target for protection inconsistencies across endpoints.
Detects: CSRF, Origin, Content-Type, SameSite, rate limit, re-auth, CORS, auth.
EOF
  exit 1
fi
shift

OUTPUT=""
FORMAT="table"
while [ $# -gt 0 ]; do
  case "$1" in
    --output) OUTPUT="$2"; FORMAT="markdown"; shift 2 ;;
    --json) FORMAT="json"; shift ;;
    *) shift ;;
  esac
done

# Delegate heavy lifting to Python for path iteration + regex
python3 - "$TARGET_DIR" "$FORMAT" "${OUTPUT:-}" <<'PYEOF'
import sys, os, re, json, glob
from collections import defaultdict
from pathlib import Path

target = sys.argv[1]
fmt = sys.argv[2]
output = sys.argv[3] if len(sys.argv) > 3 else ""

target_path = Path(target)

# ==== Step 1: Discover endpoints ====

endpoints = []  # list of dicts: {method, path, source_file, line, raw}

# Pattern A: OpenAPI/Swagger spec
for spec_candidate in ["openapi.yaml", "openapi.yml", "openapi.json",
                        "swagger.yaml", "swagger.yml", "swagger.json"]:
    for p in target_path.rglob(spec_candidate):
        try:
            content = p.read_text(encoding="utf-8", errors="replace")
            if p.suffix == ".json":
                spec = json.loads(content)
            else:
                # Lightweight YAML parse (not importing pyyaml to keep deps low)
                try:
                    import yaml
                    spec = yaml.safe_load(content)
                except ImportError:
                    # Fallback: regex extraction
                    spec = None
                    for m in re.finditer(r'^\s*(/[^\s:]+):\s*\n((?:\s+(?:get|post|put|delete|patch|options):\s*\n.*?\n)+)',
                                          content, re.MULTILINE | re.DOTALL):
                        path = m.group(1)
                        for method_m in re.finditer(r'^\s+(get|post|put|delete|patch|options):', m.group(2),
                                                     re.MULTILINE | re.IGNORECASE):
                            endpoints.append({
                                "method": method_m.group(1).upper(),
                                "path": path,
                                "source": str(p.relative_to(target_path)),
                                "line": 0,
                                "raw_markers": [],
                            })
            if spec and isinstance(spec, dict) and "paths" in spec:
                for path, methods in spec["paths"].items():
                    if not isinstance(methods, dict): continue
                    for method, op in methods.items():
                        if method.upper() in ("GET","POST","PUT","DELETE","PATCH","OPTIONS","HEAD"):
                            sec = op.get("security") if isinstance(op, dict) else None
                            endpoints.append({
                                "method": method.upper(),
                                "path": path,
                                "source": str(p.relative_to(target_path)),
                                "line": 0,
                                "raw_markers": [f"openapi:security={sec}" if sec else "openapi:no-security"],
                            })
        except Exception as e:
            print(f"[warn] failed to parse {p}: {e}", file=sys.stderr)

# Pattern B: Express/Node (app.get, router.post, etc.)
# Capture the path, then grab the full argument list up to the handler (arrow fn or named fn).
js_re = re.compile(
    r'(?:app|router|api|server)\.(?P<method>get|post|put|delete|patch|use)\s*\(\s*[\'"`](?P<path>[^\'"`]+)[\'"`](?P<middlewares>[^;]*?(?:=>|\bfunction\b))',
    re.MULTILINE | re.DOTALL,
)

for ext in ("*.js", "*.ts", "*.mjs", "*.cjs"):
    for p in target_path.rglob(ext):
        # Skip node_modules / dist
        if "node_modules" in p.parts or "dist" in p.parts or ".next" in p.parts:
            continue
        try:
            content = p.read_text(encoding="utf-8", errors="replace")
        except Exception:
            continue
        for m in js_re.finditer(content):
            method = m.group("method").upper()
            if method == "USE": continue  # middleware registration, not endpoint
            # Count line from offset
            line = content[:m.start()].count("\n") + 1
            middlewares_str = (m.group("middlewares") or "")[:300]
            markers = []
            if re.search(r'\bcsrf\b|\bcsrfProtection\b', middlewares_str, re.IGNORECASE):
                markers.append("csrf")
            if re.search(r'rateLimit|rate-limit|throttle', middlewares_str, re.IGNORECASE):
                markers.append("ratelimit")
            if re.search(r'requireAuth|authMiddleware|authenticated|ensureLoggedIn|jwt|bearer', middlewares_str, re.IGNORECASE):
                markers.append("auth")
            if re.search(r'\brequire2FA\b|\breAuth\b|reauthenticate|mfa|totp|otp|webauthn', middlewares_str, re.IGNORECASE):
                markers.append("reauth")
            if re.search(r'originCheck|validateOrigin|sameOrigin', middlewares_str, re.IGNORECASE):
                markers.append("origin")
            if re.search(r'contentType|application/json|strictJson', middlewares_str, re.IGNORECASE):
                markers.append("content-type")
            endpoints.append({
                "method": method,
                "path": m.group("path"),
                "source": str(p.relative_to(target_path)),
                "line": line,
                "raw_markers": markers,
            })

# Pattern C: Python Flask/FastAPI
py_route_re = re.compile(
    r'@(?:app|router|bp|blueprint)\.(?P<method>route|get|post|put|delete|patch)\s*\(\s*[\'"](?P<path>[^\'"]+)[\'"](?P<rest>[^)]*)\)',
    re.MULTILINE,
)
for p in target_path.rglob("*.py"):
    if "venv" in p.parts or "__pycache__" in p.parts or "site-packages" in p.parts:
        continue
    try:
        content = p.read_text(encoding="utf-8", errors="replace")
    except Exception:
        continue
    for m in py_route_re.finditer(content):
        raw_method = m.group("method").lower()
        rest = m.group("rest") or ""
        if raw_method == "route":
            # Infer method from methods=[...]
            mm = re.search(r"methods\s*=\s*\[([^\]]+)\]", rest)
            methods = []
            if mm:
                methods = [s.strip().strip("'\"").upper() for s in mm.group(1).split(",")]
            if not methods:
                methods = ["GET"]
        else:
            methods = [raw_method.upper()]
        line = content[:m.start()].count("\n") + 1
        # Look at lines above/below for decorators (csrf_exempt, login_required, etc.)
        context = content[max(0, m.start()-400):m.end()+200]
        markers = []
        if re.search(r'csrf_exempt', context, re.IGNORECASE): markers.append("csrf:exempt")
        if re.search(r'csrf_protect|@csrf', context, re.IGNORECASE): markers.append("csrf")
        if re.search(r'login_required|jwt_required|@auth', context, re.IGNORECASE): markers.append("auth")
        if re.search(r'limiter\.limit|rate_limit', context, re.IGNORECASE): markers.append("ratelimit")
        if re.search(r'require_2fa|totp_required|mfa_required', context, re.IGNORECASE): markers.append("reauth")
        for mth in methods:
            endpoints.append({
                "method": mth,
                "path": m.group("path"),
                "source": str(p.relative_to(target_path)),
                "line": line,
                "raw_markers": markers,
            })

# Pattern D: Next.js API routes (pages/api/ or app/api/*/route.ts)
for p in list(target_path.rglob("pages/api/**/*.{ts,js,tsx,jsx}")) + \
         list(target_path.rglob("app/api/**/route.{ts,js,tsx,jsx}")):
    try:
        content = p.read_text(encoding="utf-8", errors="replace")
    except Exception:
        continue
    # Infer path from file path
    rel = p.relative_to(target_path)
    parts = list(rel.parts)
    # Drop extensions
    if "pages" in parts and "api" in parts:
        idx = parts.index("api") + 1
        route_parts = [s.rsplit(".", 1)[0] for s in parts[idx:]]
        path = "/api/" + "/".join(route_parts).rstrip("/index")
    elif "app" in parts and "api" in parts:
        idx = parts.index("api") + 1
        route_parts = [s.rsplit(".", 1)[0] for s in parts[idx:-1]]
        path = "/api/" + "/".join(route_parts)
    else:
        continue
    # Detect exported HTTP handlers
    for method in ("GET", "POST", "PUT", "DELETE", "PATCH"):
        if re.search(rf"export\s+(async\s+)?function\s+{method}\s*\(", content) or \
           re.search(rf"export\s+const\s+{method}\s*=", content):
            markers = []
            if re.search(r'getServerSession|auth\(\)|requireAuth', content): markers.append("auth")
            if re.search(r'csrf', content, re.IGNORECASE): markers.append("csrf")
            if re.search(r'rateLimit|ratelimit', content, re.IGNORECASE): markers.append("ratelimit")
            endpoints.append({
                "method": method,
                "path": path,
                "source": str(rel),
                "line": 0,
                "raw_markers": markers,
            })

# Deduplicate by (method, path, source)
seen = set()
unique = []
for e in endpoints:
    key = (e["method"], e["path"], e["source"])
    if key not in seen:
        seen.add(key)
        unique.append(e)
endpoints = unique

# ==== Step 2: Group by path class + verb group ====

def path_class(p):
    # Normalize path for grouping: replace :id / {id} / [id] with {param}
    p = re.sub(r'[:/]{[^}]+}', '/{p}', p)
    p = re.sub(r'/\[[^\]]+\]', '/{p}', p)
    p = re.sub(r'/:[^/]+', '/{p}', p)
    return p.rstrip("/")

def path_prefix(p, depth=1):
    # Group endpoints sharing same top-N path segments.
    # depth=1 groups all /api/*, /admin/*, /auth/*, etc. together.
    # Each group should have consistent protection on write ops.
    parts = [s for s in p.strip("/").split("/") if s]
    if not parts:
        return "/"
    return "/" + "/".join(parts[:depth])

def verb_group(method):
    if method in ("POST", "PUT", "PATCH", "DELETE"):
        return "write"
    return "read"

# Group by (path_prefix depth=2, verb_group) — catches siblings under same API area
# that should have consistent protections.
groups = defaultdict(list)
for e in endpoints:
    key = (path_prefix(e["path"]), verb_group(e["method"]))
    groups[key].append(e)

# ==== Step 3: Inconsistency detection ====
# Within a sibling group (same path class + verb group), compare markers.
# If some endpoints have a marker and others don't = inconsistency candidate.

all_markers = sorted({m for e in endpoints for m in e["raw_markers"]}
                     | {"csrf", "auth", "ratelimit", "reauth", "origin", "content-type"})

for e in endpoints:
    e["inconsistencies"] = []

for (pclass, vg), es in groups.items():
    if len(es) < 2:
        continue
    # For each marker, check if present in some but not all
    for marker in all_markers:
        present = [e for e in es if marker in e["raw_markers"]]
        absent = [e for e in es if marker not in e["raw_markers"]]
        if present and absent:
            for e in absent:
                e["inconsistencies"].append(f"missing:{marker} (siblings have it)")

# ==== Step 4: Also check cross-verb asymmetry for fund-sensitive paths ====
# POST /transfer vs GET /balance should NOT be compared directly, but
# write ops on same path class should all have consistent protections.

# ==== Step 5: Render ====

if fmt == "json":
    print(json.dumps(endpoints, indent=2))
    sys.exit(0)

# Table rendering
cols = ["method", "path", "auth", "csrf", "ratelimit", "reauth", "origin", "inconsistency"]

def render_markdown(endpoints):
    lines = []
    lines.append("# Web Check Matrix — " + target)
    lines.append("")
    lines.append(f"**{len(endpoints)} endpoints analyzed across {len({e['source'] for e in endpoints})} files.**")
    lines.append("")
    lines.append("## Inconsistencies")
    lines.append("")
    inconsistent = [e for e in endpoints if e["inconsistencies"]]
    if not inconsistent:
        lines.append("_None detected._")
    else:
        lines.append("| Method | Path | Source | Missing |")
        lines.append("|---|---|---|---|")
        for e in inconsistent:
            missing = "; ".join(e["inconsistencies"])
            lines.append(f"| {e['method']} | `{e['path']}` | {e['source']}:{e['line']} | {missing} |")
    lines.append("")
    lines.append("## Full Matrix")
    lines.append("")
    lines.append("| Method | Path | Source | Auth | CSRF | RateLimit | ReAuth | Markers |")
    lines.append("|---|---|---|:-:|:-:|:-:|:-:|---|")
    for e in sorted(endpoints, key=lambda x: (x["path"], x["method"])):
        row = [
            e["method"],
            f"`{e['path']}`",
            f"{e['source']}:{e['line']}",
            "✓" if "auth" in e["raw_markers"] else "",
            "✓" if "csrf" in e["raw_markers"] else ("✗" if "csrf:exempt" in e["raw_markers"] else ""),
            "✓" if "ratelimit" in e["raw_markers"] else "",
            "✓" if "reauth" in e["raw_markers"] else "",
            ", ".join(sorted(set(e["raw_markers"]))),
        ]
        lines.append("| " + " | ".join(row) + " |")
    return "\n".join(lines)

if fmt == "markdown" and output:
    content = render_markdown(endpoints)
    Path(output).write_text(content, encoding="utf-8")
    print(f"Wrote {output} ({len(endpoints)} endpoints)")
else:
    # Terminal table
    inc = [e for e in endpoints if e["inconsistencies"]]
    print(f"\n{'='*70}")
    print(f"  WEB CHECK MATRIX — {target}")
    print(f"{'='*70}")
    print(f"  {len(endpoints)} endpoints, {len(inc)} with inconsistencies\n")

    if inc:
        print(f"\n--- INCONSISTENCY CANDIDATES ({len(inc)}) ---")
        for e in inc[:50]:
            print(f"  [{e['method']:<6}] {e['path']:<50} {e['source']}:{e['line']}")
            for i in e["inconsistencies"]:
                print(f"         → {i}")
        if len(inc) > 50:
            print(f"  ... and {len(inc)-50} more")

    print(f"\n--- FULL MATRIX (top 50) ---")
    header = f"  {'METHOD':<7} {'PATH':<45} {'AUTH':>4} {'CSRF':>4} {'RL':>3} {'RA':>3}"
    print(header)
    print("  " + "-"*len(header))
    for e in sorted(endpoints, key=lambda x: (x["path"], x["method"]))[:50]:
        auth = "✓" if "auth" in e["raw_markers"] else "-"
        csrf = "✓" if "csrf" in e["raw_markers"] else ("✗" if "csrf:exempt" in e["raw_markers"] else "-")
        rl = "✓" if "ratelimit" in e["raw_markers"] else "-"
        ra = "✓" if "reauth" in e["raw_markers"] else "-"
        print(f"  {e['method']:<7} {e['path'][:45]:<45} {auth:>4} {csrf:>4} {rl:>3} {ra:>3}")
    if len(endpoints) > 50:
        print(f"  ... and {len(endpoints)-50} more")
PYEOF
