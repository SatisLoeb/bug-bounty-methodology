#!/usr/bin/env python3
"""api-mapper.py — OpenAPI/Swagger endpoint mapper + IDOR test generator.

Usage:
  python3 api-mapper.py --spec openapi.json --output endpoints.md
  python3 api-mapper.py --spec openapi.json --idor --token-a TOKEN_A --token-b TOKEN_B --base-url https://api.target.com
  python3 api-mapper.py --spec openapi.json --auth-matrix --output auth-matrix.md

Features:
  1. Parse OpenAPI 2.0/3.0/3.1 specs
  2. Extract all endpoints with parameter types (path IDs, query, body)
  3. Flag IDOR-testable endpoints (any path/query param containing 'id', 'uid', 'user', 'account', 'member', 'org')
  4. Generate curl IDOR test scripts (token A accessing token B resources)
  5. Auth consistency matrix: map which endpoints require auth and what scopes
"""

import json
import sys
import argparse
import re
from pathlib import Path
from urllib.parse import urljoin


IDOR_PARAM_PATTERNS = re.compile(
    r'(id|uid|user_?id|account_?id|member_?id|org_?id|project_?id|team_?id|'
    r'wallet_?id|key_?id|branch_?id|endpoint_?id|role_?name|order_?id|'
    r'address_?id|transfer_?id|request_?id|permission_?id|snapshot_?id)',
    re.IGNORECASE
)

SENSITIVE_KEYWORDS = re.compile(
    r'(password|secret|token|key|credential|mfa|2fa|totp|withdraw|transfer|'
    r'delete|remove|admin|role|permission|invite|freeze|ban|suspend)',
    re.IGNORECASE
)


def load_spec(path):
    with open(path) as f:
        return json.load(f)


def resolve_ref(spec, ref):
    parts = ref.lstrip('#/').split('/')
    obj = spec
    for p in parts:
        obj = obj.get(p, {})
    return obj


def extract_endpoints(spec):
    endpoints = []
    base_path = spec.get('basePath', '')
    paths = spec.get('paths', {})

    for path, methods in paths.items():
        full_path = base_path + path
        path_params = re.findall(r'\{([^}]+)\}', path)
        has_idor_param = any(IDOR_PARAM_PATTERNS.search(p) for p in path_params)
        is_sensitive = bool(SENSITIVE_KEYWORDS.search(path))

        for method, details in methods.items():
            if method in ('parameters', 'servers', 'summary', 'description', '$ref'):
                continue

            method = method.upper()
            if isinstance(details, str):
                continue

            summary = details.get('summary', '')
            operation_id = details.get('operationId', '')

            # Extract auth requirements
            security = details.get('security', spec.get('security', []))
            requires_auth = bool(security)
            auth_schemes = []
            for sec in (security or []):
                auth_schemes.extend(sec.keys())

            # Extract parameters
            params = details.get('parameters', [])
            query_params = []
            body_params = []
            for p in params:
                if '$ref' in p:
                    p = resolve_ref(spec, p['$ref'])
                loc = p.get('in', '')
                name = p.get('name', '')
                required = p.get('required', False)
                if loc == 'query':
                    query_params.append({'name': name, 'required': required})
                    if IDOR_PARAM_PATTERNS.search(name):
                        has_idor_param = True
                elif loc == 'body':
                    body_params.append(name)

            # Check request body (OpenAPI 3.x)
            request_body = details.get('requestBody', {})
            if request_body:
                content = request_body.get('content', {})
                for ct, schema_info in content.items():
                    schema = schema_info.get('schema', {})
                    if '$ref' in schema:
                        schema = resolve_ref(spec, schema['$ref'])
                    for prop_name in schema.get('properties', {}).keys():
                        body_params.append(prop_name)
                        if IDOR_PARAM_PATTERNS.search(prop_name):
                            has_idor_param = True

            endpoints.append({
                'method': method,
                'path': full_path,
                'path_params': path_params,
                'query_params': query_params,
                'body_params': body_params,
                'has_idor_param': has_idor_param,
                'is_sensitive': is_sensitive,
                'requires_auth': requires_auth,
                'auth_schemes': auth_schemes,
                'summary': summary,
                'operation_id': operation_id,
            })

    return sorted(endpoints, key=lambda e: (e['path'], e['method']))


def generate_markdown(endpoints, output_path):
    lines = ['# API Endpoint Map\n']

    # Summary
    total = len(endpoints)
    idor = sum(1 for e in endpoints if e['has_idor_param'])
    sensitive = sum(1 for e in endpoints if e['is_sensitive'])
    no_auth = sum(1 for e in endpoints if not e['requires_auth'])
    lines.append(f'**Total**: {total} endpoints | **IDOR-testable**: {idor} | **Sensitive**: {sensitive} | **No auth**: {no_auth}\n')

    # IDOR targets
    lines.append('## IDOR Targets (Priority)\n')
    lines.append('| Method | Path | Params | Sensitive | Auth |')
    lines.append('|--------|------|--------|-----------|------|')
    for e in endpoints:
        if e['has_idor_param']:
            params = ', '.join(e['path_params'])
            sens = '**YES**' if e['is_sensitive'] else ''
            auth = ', '.join(e['auth_schemes']) if e['requires_auth'] else '**NONE**'
            lines.append(f"| {e['method']} | `{e['path']}` | {params} | {sens} | {auth} |")

    # Sensitive endpoints
    lines.append('\n## Sensitive Endpoints\n')
    lines.append('| Method | Path | Summary | Auth |')
    lines.append('|--------|------|---------|------|')
    for e in endpoints:
        if e['is_sensitive']:
            auth = ', '.join(e['auth_schemes']) if e['requires_auth'] else '**NONE**'
            lines.append(f"| {e['method']} | `{e['path']}` | {e['summary'][:60]} | {auth} |")

    # No-auth endpoints
    lines.append('\n## Unauthenticated Endpoints\n')
    for e in endpoints:
        if not e['requires_auth']:
            lines.append(f"- `{e['method']} {e['path']}` — {e['summary'][:80]}")

    # Full list
    lines.append('\n## All Endpoints\n')
    lines.append('| # | Method | Path | IDOR | Sensitive | Auth |')
    lines.append('|---|--------|------|------|-----------|------|')
    for i, e in enumerate(endpoints, 1):
        idor_flag = 'X' if e['has_idor_param'] else ''
        sens_flag = 'X' if e['is_sensitive'] else ''
        auth = 'Y' if e['requires_auth'] else 'N'
        lines.append(f"| {i} | {e['method']} | `{e['path']}` | {idor_flag} | {sens_flag} | {auth} |")

    text = '\n'.join(lines)
    Path(output_path).write_text(text)
    print(f'Written {len(endpoints)} endpoints to {output_path}')
    return text


def generate_idor_script(endpoints, base_url, token_a, token_b, output_path):
    lines = ['#!/bin/bash', '# Auto-generated IDOR test script', f'BASE="{base_url}"',
             f'TOKEN_A="{token_a}"', f'TOKEN_B="{token_b}"', '',
             '# TOKEN_A tries to access TOKEN_B resources', '# Replace VICTIM_ID placeholders with actual IDs from account B', '']

    test_num = 0
    for e in endpoints:
        if not e['has_idor_param']:
            continue
        test_num += 1
        path = e['path']
        for p in e['path_params']:
            path = path.replace('{' + p + '}', 'VICTIM_' + p.upper())

        if e['method'] == 'GET':
            lines.append(f'echo "=== TEST {test_num}: {e["method"]} {e["path"]} ==="')
            lines.append(f'curl -s -o /dev/null -w "HTTP %{{http_code}}" -H "Authorization: Bearer $TOKEN_A" "$BASE{path}"')
            lines.append(f'echo " — {e["summary"][:50]}"')
        elif e['method'] in ('POST', 'PUT', 'PATCH', 'DELETE'):
            lines.append(f'echo "=== TEST {test_num}: {e["method"]} {e["path"]} ==="')
            if e['method'] == 'DELETE':
                lines.append(f'curl -s -o /dev/null -w "HTTP %{{http_code}}" -X {e["method"]} -H "Authorization: Bearer $TOKEN_A" "$BASE{path}"')
            else:
                lines.append(f'curl -s -o /dev/null -w "HTTP %{{http_code}}" -X {e["method"]} -H "Authorization: Bearer $TOKEN_A" -H "Content-Type: application/json" -d \'{{}}\' "$BASE{path}"')
            lines.append(f'echo " — {e["summary"][:50]}"')
        lines.append('')

    text = '\n'.join(lines)
    Path(output_path).write_text(text)
    print(f'Written {test_num} IDOR tests to {output_path}')


def generate_auth_matrix(endpoints, output_path):
    lines = ['# Authorization Consistency Matrix\n',
             'Check: does every security-critical operation require appropriate auth level?\n',
             '| Operation | Method | Path | Auth Required | Scopes | Risk |',
             '|-----------|--------|------|---------------|--------|------|']

    for e in endpoints:
        if not (e['is_sensitive'] or e['has_idor_param']):
            continue
        auth = ', '.join(e['auth_schemes']) if e['requires_auth'] else '**NONE**'
        risk = 'CRITICAL' if e['is_sensitive'] and not e['requires_auth'] else \
               'HIGH' if e['is_sensitive'] else \
               'MEDIUM' if e['has_idor_param'] else 'LOW'
        lines.append(f"| {e['summary'][:40]} | {e['method']} | `{e['path']}` | {'Yes' if e['requires_auth'] else '**No**'} | {auth} | {risk} |")

    text = '\n'.join(lines)
    Path(output_path).write_text(text)
    print(f'Written auth matrix to {output_path}')


def main():
    parser = argparse.ArgumentParser(description='API endpoint mapper + IDOR test generator')
    parser.add_argument('--spec', required=True, help='OpenAPI spec file (JSON)')
    parser.add_argument('--output', default='endpoints.md', help='Output file')
    parser.add_argument('--idor', action='store_true', help='Generate IDOR test script')
    parser.add_argument('--auth-matrix', action='store_true', help='Generate auth consistency matrix')
    parser.add_argument('--token-a', help='Auth token for account A (attacker)')
    parser.add_argument('--token-b', help='Auth token for account B (victim)')
    parser.add_argument('--base-url', help='Base API URL')
    args = parser.parse_args()

    spec = load_spec(args.spec)
    endpoints = extract_endpoints(spec)

    if args.idor:
        if not args.base_url:
            print('ERROR: --base-url required for IDOR mode')
            sys.exit(1)
        generate_idor_script(endpoints, args.base_url, args.token_a or 'TOKEN_A', args.token_b or 'TOKEN_B',
                           args.output.replace('.md', '-idor.sh'))
        generate_markdown(endpoints, args.output)
    elif args.auth_matrix:
        generate_auth_matrix(endpoints, args.output)
    else:
        generate_markdown(endpoints, args.output)


if __name__ == '__main__':
    main()
