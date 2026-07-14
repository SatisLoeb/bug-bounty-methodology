#!/usr/bin/env python3
"""
Canary transform for the partial-vacuity guard.

Produce a copy of a Halmos test file where, INSIDE one target check_ function, every assertion call
(assert / assertEq / assertTrue / assertGt / ...) is replaced by `assert(false)`. Running Halmos on
the copy then answers ONE question: is the assertion SITE reachable by a non-reverting path?
  - Halmos finds a counterexample  -> assert(false) was reached -> site REACHABLE -> original PASS is GENUINE
  - Halmos passes (no counterexample) -> site never reached      -> original PASS was VACUOUS (false green)

The enclosing contract is renamed (suffix) so the canary file can coexist with the original.
Usage: canary.py <src.t.sol> <check_fn> <out.t.sol> [suffix]
Prints the new contract name on stdout; non-zero exit on failure.
"""
import re
import sys

ASSERT_KW = re.compile(
    r"\b(assert(?:Eq|NotEq|True|False|Gt|Lt|Ge|Le|GtEq|LtEq|EqDecimal|"
    r"ApproxEqAbs|ApproxEqRel|ApproxEqAbsDecimal|ApproxEqRelDecimal)?)\s*\("
)


def _match(text, open_idx, opench, closech):
    """Return index of the matching close char for the opener at open_idx, skipping comments/strings."""
    depth = 0
    i = open_idx
    n = len(text)
    while i < n:
        c = text[i]
        if c == "/" and i + 1 < n and text[i + 1] == "/":
            j = text.find("\n", i)
            i = n if j < 0 else j
            continue
        if c == "/" and i + 1 < n and text[i + 1] == "*":
            j = text.find("*/", i + 2)
            i = n if j < 0 else j + 2
            continue
        if c in ('"', "'"):
            q = c
            i += 1
            while i < n:
                if text[i] == "\\":
                    i += 2
                    continue
                if text[i] == q:
                    break
                i += 1
            i += 1
            continue
        if c == opench:
            depth += 1
        elif c == closech:
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return -1


def replace_asserts(body):
    """Replace every assertion call in `body` with `assert(false)`. Returns (new_body, count)."""
    out = []
    pos = 0
    count = 0
    for m in ASSERT_KW.finditer(body):
        if m.start() < pos:          # inside an already-replaced call
            continue
        open_p = m.end() - 1         # the '(' of the assertion call
        close_p = _match(body, open_p, "(", ")")
        if close_p < 0:
            continue
        out.append(body[pos:m.start()])
        out.append("assert(false)")
        pos = close_p + 1
        count += 1
    out.append(body[pos:])
    return "".join(out), count


def main():
    if len(sys.argv) < 4:
        print("usage: canary.py <src.t.sol> <check_fn> <out.t.sol> [suffix]", file=sys.stderr)
        sys.exit(2)
    src, fn, out = sys.argv[1], sys.argv[2], sys.argv[3]
    suffix = sys.argv[4] if len(sys.argv) > 4 else "NukeCanary"
    text = open(src, encoding="utf-8").read()

    fm = re.search(r"\bfunction\s+" + re.escape(fn) + r"\s*\(", text)
    if not fm:
        print(f"ERR: fonction {fn} introuvable dans {src}", file=sys.stderr)
        sys.exit(3)

    # enclosing contract = last `contract X` declared before the function
    cdecls = list(re.finditer(r"\bcontract\s+([A-Za-z_]\w*)", text[: fm.start()]))
    if not cdecls:
        print("ERR: pas de contrat englobant", file=sys.stderr)
        sys.exit(4)
    cm = cdecls[-1]
    cname = cm.group(1)
    newname = cname + suffix
    text = text[: cm.start(1)] + newname + text[cm.end(1):]

    # re-find the function on the renamed text, then its body braces
    fm = re.search(r"\bfunction\s+" + re.escape(fn) + r"\s*\(", text)
    ob = text.find("{", fm.end())
    if ob < 0:
        print("ERR: corps de fonction introuvable", file=sys.stderr)
        sys.exit(5)
    cb = _match(text, ob, "{", "}")
    if cb < 0:
        print("ERR: accolade fermante introuvable", file=sys.stderr)
        sys.exit(6)

    body = text[ob + 1: cb]
    new_body, count = replace_asserts(body)
    if count == 0:
        print(f"ERR: aucune assertion trouvée dans {fn} (rien à sonder)", file=sys.stderr)
        sys.exit(7)

    text = text[: ob + 1] + new_body + text[cb:]
    open(out, "w", encoding="utf-8").write(text)
    print(newname)


if __name__ == "__main__":
    main()
