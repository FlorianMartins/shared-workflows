"""Add `persist-credentials: false` to every actions/checkout step that lacks it.

Usage: python3 harden_checkout.py <workflow.yml>...
Line-based on purpose: keeps comments and formatting intact.
"""

import re
import sys

USES = re.compile(r"^(?P<indent>\s*)(?P<dash>- )?uses:\s*actions/checkout@")


def harden(lines: list[str]) -> list[str]:
    out: list[str] = []
    i = 0
    while i < len(lines):
        line = lines[i]
        out.append(line)
        m = USES.match(line)
        i += 1
        if not m:
            continue
        key_col = len(m["indent"]) + (2 if m["dash"] else 0)
        pad = " " * key_col
        # Look at the step's sibling keys until the step ends.
        j = i
        with_idx = None
        while j < len(lines):
            nxt = lines[j]
            if nxt.strip() == "" or nxt.lstrip().startswith("#"):
                j += 1
                continue
            col = len(nxt) - len(nxt.lstrip())
            if col < key_col or (col == key_col and nxt.lstrip().startswith("- ")):
                break
            if col == key_col and nxt.strip() == "with:":
                with_idx = j
            j += 1
        block = "".join(lines[i:j])
        if "persist-credentials" in block:
            continue
        if with_idx is None:
            out.append(f"{pad}with:\n{pad}  persist-credentials: false\n")
        else:
            out.extend(lines[i : with_idx + 1])
            out.append(f"{pad}  persist-credentials: false\n")
            i = with_idx + 1
    return out


for path in sys.argv[1:]:
    with open(path, encoding="utf-8") as fh:
        src = fh.readlines()
    dst = harden(src)
    if dst != src:
        with open(path, "w", encoding="utf-8") as fh:
            fh.writelines(dst)
        print(f"hardened {path}")
