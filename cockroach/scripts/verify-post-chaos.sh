#!/usr/bin/env bash
# Verify data integrity after a chaos test (node kill + restart).
# Checks: full replication, TPC-C consistency constraints, and warehouse balances.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=benchmark-config.env
source "$SCRIPT_DIR/benchmark-config.env"

echo "[INFO] === Post-chaos data verification ==="

echo "[INFO] 1/4 Checking all ranges are fully replicated..."
UNDER=$(docker exec cockroach1 ./cockroach sql --insecure --host=cockroach1:26257 --format=csv -e "SELECT count(*) FROM crdb_internal.ranges WHERE array_length(replicas,1) < 3;" | tail -n 1 || true)
if [ "$UNDER" = "0" ]; then
  echo "[PASS] All ranges fully replicated (3/3 nodes)."
else
  echo "[WARN] $UNDER ranges still under-replicated. Wait longer or investigate."
fi

echo ""
echo "[INFO] 2/4 Running TPC-C consistency check..."
docker exec cockroach1 ./cockroach workload check tpcc \
  --warehouses "$CHAOS_WAREHOUSES" \
  "$DB_URL"

echo ""
echo "[INFO] 3/4 Sampling warehouse YTD balances (first 5 rows)..."
docker exec cockroach1 ./cockroach sql --insecure --host=cockroach1:26257 --format=csv -e "
SELECT w_id, w_name, w_ytd FROM tpcc.warehouse ORDER BY w_id LIMIT 5;
"

echo ""
echo "[INFO] 4/4 Checking for recent serialization errors / retries..."
docker exec cockroach1 ./cockroach sql --insecure --host=cockroach1:26257 --format=csv -e "
SELECT
  sum(retries) AS total_retries_since_reset,
  count(*) AS total_statements
FROM crdb_internal.node_statement_statistics;
"

echo ""
echo "[INFO] Post-chaos verification complete."
echo "  If consistency check passes and balances look correct, data survived the fault."
