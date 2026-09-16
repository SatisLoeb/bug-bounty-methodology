"""
two_fork_replay.py — the LANDING probe for cross-deployment / reusable-signature replay (V05).

Why this exists
---------------
Every cross-chain / cross-deployment replay verdict in the corpus was REASONED, never
executed: OKX "7 mainnets, sansChainId, can't cross-collide", Across "[0u8;64] domain-sep
prefix", Stackup "useChainId flag". The First Maxim says the PRESENCE of a chainId/nonce
field is not the nullifier — only a CAPTURED signature that REJECTS on the sibling
deployment / second submission is. This script converts that hypothesis into an artifact.

The Solana-specific shape
-------------------------
A fully-signed *transaction* is bound to a recent_blockhash (~150 slots / 60-90s), so raw-tx
replay is blockhash-limited — but that window is real and a "signs per-tx" README claim does
NOT close it (mode `tx`). The higher-value seam is an APP-LEVEL ed25519-signed payload (an
off-chain maker quote / oracle attestation / operator authorization) that a program's
instruction verifies WITHOUT binding the program-id, a nonce, or the cluster — the direct
analogue of EIP-712 field-omission / sansChainId. Capture that signature once and replay it
against (a) a second submission (no on-chain nonce consumed), (b) a sibling deployment / a
different program-id, (c) a decoy context. Only a failed EXECUTED replay is a NULL.

Usage
-----
  python two_fork_replay.py \
    --rpc-a http://127.0.0.1:8899 --rpc-b http://127.0.0.1:8900 \
    --program <PROGRAM_ID> --mode payload      # payload | tx
  # rpc-a / rpc-b: two `solana-test-validator` instances (or two clusters) running the
  # SAME program (or two versions sharing the signed-payload format).

Verdict
-------
  REPLAY_ACCEPTED   the captured signature executed on B / on the 2nd submission  -> FINDING
  REPLAY_REJECTED   the sink bound program-id/nonce/cluster and rejected it       -> safe leg
  INCONCLUSIVE      could not drive the sink (wire the real ix below)

Wire the two TODO blocks (build_signed_payload_ix / build_signed_tx) to the target, then run.
"""

import argparse
import sys

try:
    from solders.keypair import Keypair
    from solders.pubkey import Pubkey
    from solders.instruction import Instruction, AccountMeta
    from solders.message import Message
    from solders.transaction import Transaction
    from solana.rpc.api import Client
except ImportError:
    print("pip install solders solana", file=sys.stderr)
    raise


def build_signed_payload_ix(program: Pubkey, signer: Keypair):
    """TODO: build the instruction that makes the program VERIFY an app-level ed25519 signature.

    The payload the program checks (e.g. `struct Quote { maker, amount, ... }`) must be signed
    HERE by `signer`. Return (instruction, captured_signature_bytes). Deliberately OMIT the
    program-id / a nonce / the cluster from the signed bytes to reproduce the defect; a hardened
    target binds them and will REJECT the replay.
    """
    payload = b"REPLACE_WITH_THE_EXACT_BYTES_THE_PROGRAM_VERIFIES"
    sig = signer.sign_message(payload)  # captured app-level signature
    data = bytes([0]) + bytes(sig) + payload  # TODO: match the ix discriminator + layout
    ix = Instruction(program, data, [AccountMeta(signer.pubkey(), True, False)])
    return ix, bytes(sig)


def build_signed_tx(client: Client, program: Pubkey, signer: Keypair) -> Transaction:
    """TODO: build a normal signed tx to test raw-tx resubmission within the blockhash window."""
    ix, _ = build_signed_payload_ix(program, signer)
    bh = client.get_latest_blockhash().value.blockhash
    msg = Message.new_with_blockhash([ix], signer.pubkey(), bh)
    return Transaction([signer], msg, bh)


def _submit(client: Client, tx: Transaction, label: str) -> bool:
    try:
        r = client.simulate_transaction(tx)  # simulate first (read logs without spending)
        logs = (r.value.logs or []) if r.value else []
        err = r.value.err if r.value else None
        print(f"[{label}] err={err}")
        for l in logs:
            print(f"[{label}]   {l}")
        return err is None
    except Exception as e:  # noqa: BLE001
        print(f"[{label}] submit raised: {e}")
        return False


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--rpc-a", required=True)
    ap.add_argument("--rpc-b", required=True)
    ap.add_argument("--program", required=True)
    ap.add_argument("--mode", choices=["payload", "tx"], default="payload")
    args = ap.parse_args()

    a, b = Client(args.rpc_a), Client(args.rpc_b)
    program = Pubkey.from_string(args.program)
    signer = Keypair()  # TODO: use the REAL authorized signer (maker/operator) keypair

    if args.mode == "payload":
        # Capture on A, then replay the SAME signed payload on B and again on A (2nd submission).
        ix, captured = build_signed_payload_ix(program, signer)
        bh_a = a.get_latest_blockhash().value.blockhash
        tx_a = Transaction([signer], Message.new_with_blockhash([ix], signer.pubkey(), bh_a), bh_a)
        ok_a = _submit(a, tx_a, "A/first")
        bh_b = b.get_latest_blockhash().value.blockhash
        tx_b = Transaction([signer], Message.new_with_blockhash([ix], signer.pubkey(), bh_b), bh_b)
        ok_b = _submit(b, tx_b, "B/sibling")
        ok_2 = _submit(a, tx_a, "A/second")
        print(f"\ncaptured signature: {captured.hex()[:24]}…")
        verdict = "REPLAY_ACCEPTED (FINDING)" if (ok_b or ok_2) else "REPLAY_REJECTED (safe leg)"
        print(f"VERDICT: {verdict}  [sibling={ok_b} second-submit={ok_2}]")
    else:
        tx = build_signed_tx(a, program, signer)
        ok_a = _submit(a, tx, "A")
        ok_b = _submit(b, tx, "B/raw-tx-window")
        print(f"VERDICT: {'REPLAY_ACCEPTED (FINDING)' if ok_b else 'REPLAY_REJECTED'}  (blockhash-window)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
