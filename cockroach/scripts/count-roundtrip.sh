#!/usr/bin/env bash
# Analyze network round-trip complexity for TPC-C NewOrder transaction.
# Replaces the weaker "lines of code" metric with a practical network metric.
set -euo pipefail

cat <<'EOF'
========================================
Network Round-trip Analysis: TPC-C NewOrder
========================================

CockroachDB (NewSQL — SQL with ACID):
  Transaction structure (single round-trip BEGIN...COMMIT block):
    1. BEGIN
    2. SELECT district (d_next_o_id, d_tax)
    3. UPDATE district (increment d_next_o_id)
    4. INSERT orders
    5. INSERT new_order
    6. For each item (5-15 items):
       - SELECT stock (s_quantity, s_dist_xx, s_ytd...)
       - UPDATE stock (decrement s_quantity, update s_ytd)
       - INSERT order_line
    7. UPDATE warehouse (w_ytd) — optional depending on implementation
    8. COMMIT

  Network round-trips (client → server):
    - With standard driver (psycopg2 / libpq):
      ~1 round-trip per statement if not pipelined
      => ~15–35 round-trips total
    - With pipelining / batching:
      => ~3–5 round-trips (BEGIN + pipelined batch + COMMIT)
    - CockroachDB can execute multi-table ops inside 1 txn
      without the client managing intermediate state.

MongoDB (NoSQL — Document, default no multi-doc txn):
  Without multi-document transaction:
    - Read district document                         → 1 RT
    - Update district document                         → 1 RT
    - Insert order document                            → 1 RT
    - Insert new_order document                        → 1 RT
    - For each item (5–15 items):
      - Read stock document                            → 1 RT each
      - Update stock document                          → 1 RT each
      - Insert order_line document                     → 1 RT each
    - Update warehouse document                        → 1 RT
    => Total: ~18–48 round-trips, each with w:1 or w:majority latency

  WITH multi-document transaction (MongoDB 4.0+):
    - startTransaction                                 → 1 RT
    - Same ~18–48 document operations (still need docs)
    - commit (waits for w:majority journal acknowledgement) → 1 RT
    => Total: ~20–50 round-trips, but ACID guaranteed at commit point.

Key difference:
  SQL ACID bundles 5–8 logical table operations into a single server-side
  transaction plan. The client sends SQL text once; the server resolves
  JOINs, FKs, and row locks internally. NoSQL must either:
    (a) do many independent document round-trips (eventual consistency risk), or
    (b) wrap them in a multi-document transaction (high coordination cost).

========================================
EOF

echo ""
echo "[INFO] For empirical measurement, capture network traffic during benchmark:"
echo "  CockroachDB: tcpdump -i any port 26257"
echo "  MongoDB:     mongostat --host <host>:27017 1"
echo ""
echo "[INFO] This metric is more meaningful than SLOC for distributed DB comparison."
