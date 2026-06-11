| D8 | **Weight anchored (all non-Informational findings)** | For every finding claiming severity ≥ Low with a dollar impact: the report contains at least one numerical anchor — either W1 (computed dollar loss with formula and inputs) or W5 (≥1 paid precedent with dollar figure from H1/C4/Cantina/Sherlock). DoS findings may use the W1 alternate anchor `downtime × req/s × users` from a reproducible PoC. Smart-contract findings with forge-test state delta assertions auto-pass W1. Dashboard slots W2 (stakeholder map), W3 (reversibility), W4 (live conditions) are optional but their absence is a noted weakness. An unpaid "related H1 #xxx" does NOT satisfy W5 — only paid references with dollar amounts count. Run `arsenal/tools/precedent-scan.sh <class>` to populate W5 fast. **This criterion is GATING** — D8 fail = do not submit at claimed severity; downgrade or strengthen. | [ ] 1 / [ ] 0 / [ ] N/A (Informational only) |

**D subtotal: ___/6** (6 scored + 2 gating)

---
