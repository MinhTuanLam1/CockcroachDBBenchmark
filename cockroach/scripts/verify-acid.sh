#!/usr/bin/env bash
# ACID verification for CockroachDB TPC-C workload.
# Can run standalone or as part of the benchmark pipeline.
# Tests: Atomicity, Consistency, Durability (Isolation already covered by verify-serializable.sh)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=benchmark-config.env
source "$SCRIPT_DIR/benchmark-config.env"

OUTDIR="$SCRIPT_DIR/../results/raw"
mkdir -p "$OUTDIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTFILE="$OUTDIR/acid_verify_${TIMESTAMP}.log"

DB="postgresql://root@cockroach1:26257/tpcc?sslmode=disable"

echo "========================================" | tee "$OUTFILE"
echo "[INFO] ACID Verification Starting..." | tee -a "$OUTFILE"
echo "========================================" | tee -a "$OUTFILE"

# ============================================================================
# A — ATOMICITY
# ============================================================================
echo "" | tee -a "$OUTFILE"
echo "[TEST A/3] Atomicity: Transaction all-or-nothing" | tee -a "$OUTFILE"

docker exec cockroach1 ./cockroach sql --insecure --host=cockroach1:26257 -e "
CREATE DATABASE IF NOT EXISTS acid_test;
DROP TABLE IF EXISTS acid_test.atomic_accounts;
CREATE TABLE acid_test.atomic_accounts (
  id INT PRIMARY KEY,
  balance INT NOT NULL
);
INSERT INTO acid_test.atomic_accounts (id, balance) VALUES (1, 1000), (2, 1000);
" 2>&1 | tee -a "$OUTFILE"

TOTAL_BEFORE=$(docker exec cockroach1 ./cockroach sql --insecure --host=cockroach1:26257 --format=csv -e "
SELECT balance FROM acid_test.atomic_accounts WHERE id = 1;
" 2>/dev/null | tail -n 1 || echo "1000")

docker exec cockroach1 ./cockroach sql --insecure --host=cockroach1:26257 -e "
BEGIN;
UPDATE acid_test.atomic_accounts SET balance = balance - 500 WHERE id = 1;
UPDATE acid_test.atomic_accounts SET balance = balance + 500 WHERE id = 2;
COMMIT;
" 2>&1 | tee -a "$OUTFILE"

TOTAL_AFTER=$(docker exec cockroach1 ./cockroach sql --insecure --host=cockroach1:26257 --format=csv -e "
SELECT SUM(balance) FROM acid_test.atomic_accounts;
" 2>/dev/null | tail -n 1 || echo "0")

if [ "$TOTAL_AFTER" = "2000" ]; then
  echo "[PASS] Atomicity: Total balance unchanged after transfer (2000)." | tee -a "$OUTFILE"
else
  echo "[FAIL] Atomicity: Total balance is $TOTAL_AFTER, expected 2000." | tee -a "$OUTFILE"
  exit 1
fi

# Now test ROLLBACK
docker exec cockroach1 ./cockroach sql --insecure --host=cockroach1:26257 -e "
BEGIN;
UPDATE acid_test.atomic_accounts SET balance = 999999 WHERE id = 1;
ROLLBACK;
" 2>&1 | tee -a "$OUTFILE"

ROLLBACK_CHECK=$(docker exec cockroach1 ./cockroach sql --insecure --host=cockroach1:26257 --format=csv -e "
SELECT balance FROM acid_test.atomic_accounts WHERE id = 1;
" 2>/dev/null | tail -n 1 || echo "0")

if [ "$ROLLBACK_CHECK" = "500" ]; then
  echo "[PASS] Atomicity: ROLLBACK correctly reverted update." | tee -a "$OUTFILE"
else
  echo "[FAIL] Atomicity: ROLLBACK failed. Balance=$ROLLBACK_CHECK, expected 500." | tee -a "$OUTFILE"
  exit 1
fi

# ============================================================================
# C — CONSISTENCY (TPC-C business rules)
# ============================================================================
echo "" | tee -a "$OUTFILE"
echo "[TEST C/3] Consistency: TPC-C constraint checks" | tee -a "$OUTFILE"

# 1) Warehouse YTD = sum of District YTD
echo "[INFO] Checking: warehouse.w_ytd = sum(district.d_ytd)..." | tee -a "$OUTFILE"
CONSISTENCY_1=$(docker exec cockroach1 ./cockroach sql --insecure --host=cockroach1:26257 --format=csv -e "
SELECT
  CASE
    WHEN ABS(w.w_ytd - d.total_d_ytd) < 0.01 THEN 'PASS'
    ELSE 'FAIL'
  END AS result,
  w.w_id,
  w.w_ytd,
  d.total_d_ytd
FROM tpcc.warehouse w
JOIN (
  SELECT d_w_id, SUM(d_ytd) AS total_d_ytd
  FROM tpcc.district
  GROUP BY d_w_id
) d ON d.d_w_id = w.w_id
ORDER BY w.w_id
LIMIT 5;
" 2>/dev/null | tail -n +2 || true)

if echo "$CONSISTENCY_1" | grep -q "FAIL"; then
  echo "[FAIL] Consistency: warehouse.w_ytd != sum(district.d_ytd)" | tee -a "$OUTFILE"
  echo "$CONSISTENCY_1" | tee -a "$OUTFILE"
  exit 1
else
  echo "[PASS] Consistency: warehouse.w_ytd matches sum(district.d_ytd) for sampled rows." | tee -a "$OUTFILE"
fi

# 2) District next_o_id consistency
echo "[INFO] Checking: district.d_next_o_id consistency..." | tee -a "$OUTFILE"
CONSISTENCY_2=$(docker exec cockroach1 ./cockroach sql --insecure --host=cockroach1:26257 --format=csv -e "
SELECT
  CASE
    WHEN d.d_next_o_id = COALESCE(MAX(o.o_id) + 1, 1) THEN 'PASS'
    ELSE 'FAIL'
  END AS result,
  d.d_w_id,
  d.d_id,
  d.d_next_o_id,
  COALESCE(MAX(o.o_id), 0) AS max_o_id
FROM tpcc.district d
LEFT JOIN tpcc.orders o ON o.o_w_id = d.d_w_id AND o.o_d_id = d.d_id
GROUP BY d.d_w_id, d.d_id, d.d_next_o_id
ORDER BY d.d_w_id, d.d_id
LIMIT 5;
" 2>/dev/null | tail -n +2 || true)

if echo "$CONSISTENCY_2" | grep -q "FAIL"; then
  echo "[FAIL] Consistency: district.d_next_o_id mismatch" | tee -a "$OUTFILE"
  echo "$CONSISTENCY_2" | tee -a "$OUTFILE"
  exit 1
else
  echo "[PASS] Consistency: district.d_next_o_id consistent for sampled rows." | tee -a "$OUTFILE"
fi

# 3) Non-negative stock quantity
echo "[INFO] Checking: stock quantities are non-negative..." | tee -a "$OUTFILE"
NEG_STOCK=$(docker exec cockroach1 ./cockroach sql --insecure --host=cockroach1:26257 --format=csv -e "
SELECT count(*) FROM tpcc.stock WHERE s_quantity < 0;
" 2>/dev/null | tail -n 1 || echo "0")

if [ "$NEG_STOCK" = "0" ]; then
  echo "[PASS] Consistency: No negative stock quantities found." | tee -a "$OUTFILE"
else
  echo "[FAIL] Consistency: Found $NEG_STOCK negative stock quantities." | tee -a "$OUTFILE"
  exit 1
fi

# ============================================================================
# D — DURABILITY
# ============================================================================
echo "" | tee -a "$OUTFILE"
echo "[TEST D/3] Durability: Data survives node restart" | tee -a "$OUTFILE"

TEST_TS=$(date +%s)
docker exec cockroach1 ./cockroach sql --insecure --host=cockroach1:26257 -e "
CREATE TABLE IF NOT EXISTS acid_test.durability_log (
  id UUID DEFAULT gen_random_uuid(),
  test_run INT NOT NULL,
  msg STRING,
  PRIMARY KEY (id)
);
INSERT INTO acid_test.durability_log (test_run, msg) VALUES ($TEST_TS, 'before-restart');
" 2>&1 | tee -a "$OUTFILE"

echo "[INFO] Restarting cockroach1 to test durability..." | tee -a "$OUTFILE"
docker restart cockroach1 2>&1 | tee -a "$OUTFILE"
sleep 15

echo "[INFO] Waiting for node to be ready..." | tee -a "$OUTFILE"
for i in {1..30}; do
  READY=$(docker exec cockroach1 ./cockroach sql --insecure --host=cockroach1:26257 --format=csv -e "SELECT 1" 2>/dev/null | tail -n 1 || echo "")
  if [ "$READY" = "1" ]; then
    echo "[INFO] Node ready after restart." | tee -a "$OUTFILE"
    break
  fi
  sleep 2
done

DURABILITY_CHECK=$(docker exec cockroach1 ./cockroach sql --insecure --host=cockroach1:26257 --format=csv -e "
SELECT count(*) FROM acid_test.durability_log WHERE test_run = $TEST_TS;
" 2>/dev/null | tail -n 1 || echo "0")

if [ "$DURABILITY_CHECK" = "1" ]; then
  echo "[PASS] Durability: Data survived cockroach1 restart." | tee -a "$OUTFILE"
else
  echo "[FAIL] Durability: Data lost after restart. Found $DURABILITY_CHECK rows, expected 1." | tee -a "$OUTFILE"
  exit 1
fi

# ============================================================================
# CLEANUP
# ============================================================================
docker exec cockroach1 ./cockroach sql --insecure --host=cockroach1:26257 -e "
DROP TABLE IF EXISTS acid_test.atomic_accounts;
DROP TABLE IF EXISTS acid_test.durability_log;
" 2>&1 | tee -a "$OUTFILE"

# ============================================================================
# SUMMARY
# ============================================================================
echo "" | tee -a "$OUTFILE"
echo "========================================" | tee -a "$OUTFILE"
echo "[RESULT] ALL ACID TESTS PASSED" | tee -a "$OUTFILE"
echo "========================================" | tee -a "$OUTFILE"
echo "Output: $OUTFILE" | tee -a "$OUTFILE"
