#!/usr/bin/env python3
"""api-auth.py — Generic API authenticator/signer for crypto exchanges.

Usage:
  python3 api-auth.py --exchange bybit --key KEY --secret SECRET --method GET --path /v5/user/query-api
  python3 api-auth.py --exchange bybit --key KEY --secret SECRET --method POST --path /v5/order/create --body '{"category":"spot"}'
  python3 api-auth.py --exchange binance --key KEY --secret SECRET --method GET --path /api/v3/account

Supported exchanges: bybit, binance, okx, coinbase, kraken, gate, bitget, kucoin

Outputs: full curl command with correct auth headers/signatures.
"""

import argparse
import hashlib
import hmac
import base64
import time
import json
import sys
from urllib.parse import urlencode


EXCHANGES = {
    'bybit': {
        'testnet': 'https://api-testnet.bybit.com',
        'mainnet': 'https://api.bybit.com',
        'sign_method': 'bybit_hmac',
    },
    'binance': {
        'testnet': 'https://testnet.binance.vision',
        'mainnet': 'https://api.binance.com',
        'sign_method': 'binance_hmac',
    },
    'okx': {
        'testnet': 'https://www.okx.com',  # OKX uses same domain with demo flag
        'mainnet': 'https://www.okx.com',
        'sign_method': 'okx_hmac',
    },
    'coinbase': {
        'testnet': 'https://api-public.sandbox.exchange.coinbase.com',
        'mainnet': 'https://api.exchange.coinbase.com',
        'sign_method': 'coinbase_hmac',
    },
    'gate': {
        'testnet': 'https://api.gateio.ws',
        'mainnet': 'https://api.gateio.ws',
        'sign_method': 'gate_hmac',
    },
    'kraken': {
        'testnet': 'https://api.kraken.com',
        'mainnet': 'https://api.kraken.com',
        'sign_method': 'kraken_hmac',
    },
    'bitget': {
        'testnet': 'https://api.bitget.com',
        'mainnet': 'https://api.bitget.com',
        'sign_method': 'bitget_hmac',
    },
    'kucoin': {
        'testnet': 'https://openapi-sandbox.kucoin.com',
        'mainnet': 'https://api.kucoin.com',
        'sign_method': 'kucoin_hmac',
    },
}


def hmac_sha256(key, msg):
    return hmac.new(key.encode(), msg.encode(), hashlib.sha256).hexdigest()


def hmac_sha256_b64(key, msg):
    return base64.b64encode(hmac.new(key.encode(), msg.encode(), hashlib.sha256).digest()).decode()


def sign_bybit(key, secret, method, path, params='', body='', timestamp=None):
    ts = timestamp or str(int(time.time() * 1000))
    recv_window = '5000'
    if method == 'GET':
        payload = f'{ts}{key}{recv_window}{params}'
    else:
        payload = f'{ts}{key}{recv_window}{body}'
    sign = hmac_sha256(secret, payload)
    base_url = EXCHANGES['bybit']['testnet']

    headers = [
        f'-H "X-BAPI-API-KEY: {key}"',
        f'-H "X-BAPI-TIMESTAMP: {ts}"',
        f'-H "X-BAPI-SIGN: {sign}"',
        f'-H "X-BAPI-RECV-WINDOW: {recv_window}"',
    ]
    if method == 'GET':
        url = f'{base_url}{path}{"?" + params if params else ""}'
        return f'curl -s {" ".join(headers)} "{url}"'
    else:
        headers.append('-H "Content-Type: application/json"')
        url = f'{base_url}{path}'
        return f'curl -s -X {method} {" ".join(headers)} -d \'{body}\' "{url}"'


def sign_binance(key, secret, method, path, params='', body='', timestamp=None):
    ts = timestamp or str(int(time.time() * 1000))
    query = f'{params}&timestamp={ts}' if params else f'timestamp={ts}'
    sign = hmac_sha256(secret, query)
    query += f'&signature={sign}'
    base_url = EXCHANGES['binance']['testnet']

    headers = [f'-H "X-MBX-APIKEY: {key}"']
    if method == 'GET':
        return f'curl -s {" ".join(headers)} "{base_url}{path}?{query}"'
    else:
        headers.append('-H "Content-Type: application/x-www-form-urlencoded"')
        return f'curl -s -X {method} {" ".join(headers)} -d "{query}" "{base_url}{path}"'


def sign_okx(key, secret, method, path, params='', body='', timestamp=None, passphrase=''):
    ts = timestamp or time.strftime('%Y-%m-%dT%H:%M:%S.000Z', time.gmtime())
    if method == 'GET' and params:
        pre_sign = f'{ts}{method}{path}?{params}'
    else:
        pre_sign = f'{ts}{method}{path}{body}'
    sign = hmac_sha256_b64(secret, pre_sign)
    base_url = EXCHANGES['okx']['mainnet']

    headers = [
        f'-H "OK-ACCESS-KEY: {key}"',
        f'-H "OK-ACCESS-SIGN: {sign}"',
        f'-H "OK-ACCESS-TIMESTAMP: {ts}"',
        f'-H "OK-ACCESS-PASSPHRASE: {passphrase}"',
    ]
    if method == 'GET':
        url = f'{base_url}{path}{"?" + params if params else ""}'
        return f'curl -s {" ".join(headers)} "{url}"'
    else:
        headers.append('-H "Content-Type: application/json"')
        return f'curl -s -X {method} {" ".join(headers)} -d \'{body}\' "{base_url}{path}"'


def sign_gate(key, secret, method, path, params='', body='', timestamp=None):
    ts = timestamp or str(int(time.time()))
    body_hash = hashlib.sha512(body.encode()).hexdigest() if body else hashlib.sha512(b'').hexdigest()
    pre_sign = f'{method}\n{path}\n{params}\n{body_hash}\n{ts}'
    sign = hmac.new(secret.encode(), pre_sign.encode(), hashlib.sha512).hexdigest()
    base_url = EXCHANGES['gate']['mainnet']

    headers = [
        f'-H "KEY: {key}"',
        f'-H "SIGN: {sign}"',
        f'-H "Timestamp: {ts}"',
    ]
    if method == 'GET':
        url = f'{base_url}{path}{"?" + params if params else ""}'
        return f'curl -s {" ".join(headers)} "{url}"'
    else:
        headers.append('-H "Content-Type: application/json"')
        return f'curl -s -X {method} {" ".join(headers)} -d \'{body}\' "{base_url}{path}"'


def sign_kucoin(key, secret, method, path, params='', body='', timestamp=None, passphrase='', api_version='2'):
    ts = timestamp or str(int(time.time() * 1000))
    if method == 'GET' and params:
        str_to_sign = f'{ts}{method}/api{path}?{params}'
    else:
        str_to_sign = f'{ts}{method}/api{path}{body}'
    sign = hmac_sha256_b64(secret, str_to_sign)
    pp_sign = hmac_sha256_b64(secret, passphrase)
    base_url = EXCHANGES['kucoin']['testnet']

    headers = [
        f'-H "KC-API-KEY: {key}"',
        f'-H "KC-API-SIGN: {sign}"',
        f'-H "KC-API-TIMESTAMP: {ts}"',
        f'-H "KC-API-PASSPHRASE: {pp_sign}"',
        f'-H "KC-API-KEY-VERSION: {api_version}"',
    ]
    url = f'{base_url}/api{path}{"?" + params if params else ""}'
    if method == 'GET':
        return f'curl -s {" ".join(headers)} "{url}"'
    else:
        headers.append('-H "Content-Type: application/json"')
        return f'curl -s -X {method} {" ".join(headers)} -d \'{body}\' "{base_url}/api{path}"'


SIGNERS = {
    'bybit': sign_bybit,
    'binance': sign_binance,
    'okx': sign_okx,
    'gate': sign_gate,
    'kucoin': sign_kucoin,
}


def main():
    parser = argparse.ArgumentParser(description='Crypto exchange API signer')
    parser.add_argument('--exchange', required=True, choices=list(EXCHANGES.keys()))
    parser.add_argument('--key', required=True, help='API key')
    parser.add_argument('--secret', required=True, help='API secret')
    parser.add_argument('--method', default='GET', choices=['GET', 'POST', 'PUT', 'DELETE', 'PATCH'])
    parser.add_argument('--path', required=True, help='API path (e.g., /v5/user/query-api)')
    parser.add_argument('--params', default='', help='Query parameters (key=val&key2=val2)')
    parser.add_argument('--body', default='', help='Request body (JSON string)')
    parser.add_argument('--passphrase', default='', help='API passphrase (OKX, KuCoin)')
    parser.add_argument('--execute', action='store_true', help='Execute the curl command')
    parser.add_argument('--mainnet', action='store_true', help='Use mainnet instead of testnet')
    args = parser.parse_args()

    signer = SIGNERS.get(args.exchange)
    if not signer:
        print(f'Signer not implemented for {args.exchange}. Supported: {", ".join(SIGNERS.keys())}')
        sys.exit(1)

    kwargs = {
        'key': args.key, 'secret': args.secret,
        'method': args.method, 'path': args.path,
        'params': args.params, 'body': args.body,
    }
    if args.exchange in ('okx', 'kucoin'):
        kwargs['passphrase'] = args.passphrase

    cmd = signer(**kwargs)

    if args.mainnet:
        testnet_url = EXCHANGES[args.exchange]['testnet']
        mainnet_url = EXCHANGES[args.exchange]['mainnet']
        cmd = cmd.replace(testnet_url, mainnet_url)

    print(cmd)

    if args.execute:
        import subprocess
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        print(result.stdout)
        if result.stderr:
            print(result.stderr, file=sys.stderr)


if __name__ == '__main__':
    main()
