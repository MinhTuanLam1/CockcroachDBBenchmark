# TPC-C CockroachDB Benchmark Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deploy a 3-node CockroachDB cluster, execute standardized TPC-C benchmarks, measure ACID overhead via latency/throughput/retry metrics, perform chaos engineering, and produce analysis artifacts for comparison with MongoDB team.

**Architecture:** Docker Compose for 3-node cluster (`cockroach1`, `cockroach2`, `cockroach3`) with shared network and persistent volumes. Benchmark via `cockroach workload tpcc`. Monitoring via built-in Admin UI (`:8080`) and custom shell scripts parsing `SHOW`/`EXPLAIN` output.

**Tech Stack:** CockroachDB v24.1+, Docker Compose, shell/bash, Python 3 (matplotlib/pandas for charts), OLTPBench (optional fallback)

---

## File Structure

```
/Users/tuan/Documents/AdvancedDB/
├── cockroach/
│   ├── docker/
│   │   └── docker-compose.yml          # 3-node CockroachDB cluster definition
│   ├── scripts/
│   │   ├── setup.sh                    # Init cluster, create DB/user, run cockroach workload init
│   │   ├── benchmark.sh                # Run TPC-C workload with varying warehouse counts
│   │   ├── latency-monitor.sh          # Poll SQL for p50/p95/p99 per txn type via SHOW STATEMENTS
│   │   ├── chaos-kill.sh               # Kill a node, measure recovery
│   │   └── analyze.py                  # Parse cockroach workload output into CSV + charts
│   ├── results/
│   │   ├── raw/                        # stdout/stderr logs from each benchmark run
│   │   ├── latency/                    # Per-txn-type latency snapshots
│   │   ├── screenshots/                # Admin UI screen captures during chaos
│   │   └── csv/                        # Processed tpmC/latency/retry/overhead data
│   └── analysis/
│       └── charts.ipynb                # Jupyter notebook generating comparison charts
├── shared/
│   └── comparison-template.md          # Joint conclusion template with MongoDB team
└── docs/superpowers/plans/
    └── 2026-05-20-tpc-c-cockroachdb-benchmark.md   # This file
```

---

## Prerequisites

- Docker Desktop installed and running
- `docker-compose` or `docker compose` available
- `cockroach` CLI installed locally (for workload generation)
- Python 3 with `pandas`, `matplotlib`, `jupyter` (for analysis)
- `ffmpeg` or QuickTime (for screen recording)
- Ports 26257 (SQL), 8080 (Admin UI) available on localhost

---

## Task 1: Initialize Project Folders and Docker Compose

**Files:**
- Create: `cockroach/docker/docker-compose.yml`
- Create: `cockroach/scripts/setup.sh`
- Create: `cockroach/results/raw/.gitkeep`
- Create: `cockroach/results/latency/.gitkeep`
- Create: `cockroach/results/screenshots/.gitkeep`
- Create: `cockroach/results/csv/.gitkeep`
- Create: `shared/comparison-template.md`

- [ ] **Step 1.1: Create directory structure**

Run:
```bash
mkdir -p cockroach/{docker,scripts,results/{raw,latency,screenshots,csv},analysis}
mkdir -p shared
touch cockroach/results/{raw,latency,screenshots,csv}/.gitkeep
```

- [ ] **Step 1.2: Write Docker Compose for 3-node CockroachDB cluster**

`cockroach/docker/docker-compose.yml`:
```yaml
version: '3.8'

services:
  cockroach1:
    image: cockroachdb/cockroach:latest-v24.1
    container_name: cockroach1
    hostname: cockroach1
    ports:
      - "26257:26257"
      - "8080:8080"
    volumes:
      - cockroach-data1:/cockroach/cockroach-data
    command: >
      start --insecure --join=cockroach1,cockroach2,cockroach3
      --listen-addr=cockroach1:26257
      --http-addr=cockroach1:8080
      --advertise-addr=cockroach1:26257
    networks:
      - cockroach-net

  cockroach2:
    image: cockroachdb/cockroach:latest-v24.1
    container_name: cockroach2
    hostname: cockroach2
    ports:
      - "26258:26257"
      - "8081:8080"
    volumes:
      - cockroach-data2:/cockroach/cockroach-data
    command: >
      start --insecure --join=cockroach1,cockroach2,cockroach3
      --listen-addr=cockroach2:26257
      --http-addr=cockroach2:8080
      --advertise-addr=cockroach2:26257
    networks:
      - cockroach-net

  cockroach3:
    image: cockroachdb/cockroach:latest-v24.1
    container_name: cockroach3
    hostname: cockroach3
    ports:
      - "26259:26257"
      - "8082:8080"
    volumes:
      - cockroach-data3:/cockroach/cockroach-data
    command: >
      start --insecure --join=cockroach1,cockroach2,cockroach3
      --listen-addr=cockroach3:26257
      --http-addr=cockroach3:8080
      --advertise-addr=cockroach3:26257
    networks:
      - cockroach-net

volumes:
  cockroach-data1:
  cockroach-data2:
  cockroach-data3:

networks:
  cockroach-net:
    driver: bridge
```

- [ ] **Step 1.3: Write cluster setup script**

`cockroach/scripts/setup.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../docker"

echo "[1/4] Starting containers..."
docker-compose up -d

echo "[2/4] Waiting for nodes to be ready..."
sleep 5

echo "[3/4] Initializing cluster ( Raft quorum )..."
docker exec cockroach1 ./cockroach init --insecure --host=cockroach1:26257

echo "[4/4] Cluster initialized. Nodes:"
docker exec cockroach1 ./cockroach node ls --insecure --host=cockroach1:26257

echo "Done. Admin UI available at http://localhost:8080"
```

Make executable: `chmod +x cockroach/scripts/setup.sh`

- [ ] **Step 1.4: Write shared comparison template**

`shared/comparison-template.md`:
```markdown
# TPC-C Comparison: CockroachDB vs MongoDB

## Benchmark Parameters
- Warehouses tested: 10, 50, 100, 500
- Duration per run: 10 minutes (warmup + 5 min steady state)

## Performance Chart Data
| Warehouses | tpmC (CRDB) | Latency p99 (CRDB) | tpmC (Mongo) | Latency p99 (Mongo) |
|------------|-------------|--------------------|--------------|---------------------|
| 10         |             |                    |              |                     |
| 50         |             |                    |              |                     |
| 100        |             |                    |              |                     |
| 500        |             |                    |              |                     |

## Fault Tolerance
| Metric | CockroachDB | MongoDB |
|--------|-------------|---------|
| Node kill to recovery | | |
| Success rate during fault | | |
| Downtime observed | | |

## Consistency Overhead
| Configuration | tpmC | % Drop |
|---------------|------|--------|
| CRDB 1-node (baseline) | | — |
| CRDB 3-node (Raft) | | |
| Mongo w:1 | | |
| Mongo w:majority + j:true | | |

## Conclusion
- Crossover threshold (when NewSQL beats NoSQL):
- Recommended use cases per database:
```

- [ ] **Step 1.5: Commit folder skeleton**

```bash
git add cockroach/ shared/ docs/
git commit -m "chore: init project folders and docker-compose for CRDB cluster"
```

---

## Task 2: Start Cluster and Verify Health

**Files:**
- Modify: `cockroach/scripts/setup.sh` (run it)
- Test: Admin UI reachable at http://localhost:8080

- [ ] **Step 2.1: Execute setup script**

Run:
```bash
cd /Users/tuan/Documents/AdvancedDB
./cockroach/scripts/setup.sh
```
Expected output: `Cluster initialized. Admin UI available at http://localhost:8080`

- [ ] **Step 2.2: Verify 3-node membership**

Run:
```bash
docker exec cockroach1 ./cockroach node ls --insecure --host=cockroach1:26257
```
Expected: 3 rows with status `LIVE`.

- [ ] **Step 2.3: Verify Raft replication**

Run:
```bash
docker exec -it cockroach1 ./cockroach sql --insecure --host=cockroach1:26257 -e "SELECT * FROM crdb_internal.ranges WHERE database_name='system' LIMIT 5;"
```
Expected: `replicas` column shows 3 replicas per range.

---

## Task 3: Initialize TPC-C Schema and Run First Benchmark (10 Warehouses)

**Files:**
- Create: `cockroach/scripts/benchmark.sh`

- [ ] **Step 3.1: Write benchmark script**

`cockroach/scripts/benchmark.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail

WAREHOUSES="${1:-10}"
DURATION="${2:-5m}"
RAMP="${3:-1m}"
OUTDIR="$(dirname "$0")/../results/raw"
mkdir -p "$OUTDIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTFILE="$OUTDIR/tpcc_${WAREHOUSES}wh_${TIMESTAMP}.log"

echo "[INFO] Running TPC-C: warehouses=$WAREHOUSES, duration=$DURATION, ramp=$RAMP"
echo "[INFO] Output: $OUTFILE"

cockroach workload run tpcc \
  --warehouses "$WAREHOUSES" \
  --duration "$DURATION" \
  --ramp "$RAMP" \
  --tolerate-errors \
  "postgresql://root@cockroach1:26257?sslmode=disable" \
  | tee "$OUTFILE"

echo "[INFO] Benchmark complete. Results saved to $OUTFILE"
```

Make executable: `chmod +x cockroach/scripts/benchmark.sh`

- [ ] **Step 3.2: Initialize workload schema (run once)**

Run:
```bash
cd /Users/tuan/Documents/AdvancedDB
cockroach workload init tpcc \
  --warehouses 10 \
  "postgresql://root@cockroach1:26257?sslmode=disable"
```
Expected: Tables created (`warehouse`, `district`, `customer`, `history`, `order`, `new_order`, `item`, `stock`).

- [ ] **Step 3.3: Run first benchmark (10 wh, 5 min)**

Run:
```bash
./cockroach/scripts/benchmark.sh 10 5m 1m
```
Expected: Output file in `cockroach/results/raw/tpcc_10wh_*.log` with tpmC and latency summary.

---

## Task 4: Measure Latency per Transaction Type (p50/p95/p99)

**Files:**
- Create: `cockroach/scripts/latency-monitor.sh`
- Create: `cockroach/results/latency/latency_10wh_baseline.json`

- [ ] **Step 4.1: Write latency capture script**

`cockroach/scripts/latency-monitor.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail

OUTDIR="$(dirname "$0")/../results/latency"
mkdir -p "$OUTDIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTFILE="$OUTDIR/latency_${TIMESTAMP}.json"

SQL=$(cat <<'EOF'
SELECT
  app_name,
  statement,
  P50_LATENCY(sql) AS p50,
  P95_LATENCY(sql) AS p95,
  P99_LATENCY(sql) AS p99
FROM crdb_internal.statement_statistics
WHERE app_name = '$ cockroach workload'
ORDER BY statement;
EOF
)

echo "[INFO] Capturing latency stats to $OUTFILE"
docker exec -it cockroach1 ./cockroach sql --insecure --host=cockroach1:26257 --format=json -e "$SQL" > "$OUTFILE"
echo "[INFO] Done."
```

**Note:** If `crdb_internal.statement_statistics` latency functions vary by version, fallback to parsing `cockroach workload` output which already prints:
```
_elapsed_______tpmC____efc__avg(ms)__p50(ms)__p95(ms)__p99(ms)_pMax(ms)
```
per transaction type (`newOrder`, `payment`, `orderStatus`, `delivery`, `stockLevel`).

Make executable: `chmod +x cockroach/scripts/latency-monitor.sh`

- [ ] **Step 4.2: Parse workload output into structured latency JSON**

Write a one-liner to parse the benchmark log:
```bash
grep -E "newOrder|payment|orderStatus|delivery|stockLevel" cockroach/results/raw/tpcc_10wh_*.log \
  | awk '{print "{\"txn\":\"" $1 "\",\"tpmC\":" $2 ",\"avg_ms\":" $4 ",\"p50_ms\":" $5 ",\"p95_ms\":" $6 ",\"p99_ms\":" $7 "}"}' \
  > cockroach/results/latency/latency_10wh_baseline.json
```

- [ ] **Step 4.3: Verify latency file content**

Run:
```bash
cat cockroach/results/latency/latency_10wh_baseline.json | head -n 5
```
Expected: 5 JSON lines with keys `txn`, `tpmC`, `avg_ms`, `p50_ms`, `p95_ms`, `p99_ms`.

---

## Task 5: Capture Conflict Retry Metrics Under SERIALIZABLE

**Files:**
- Create: `cockroach/scripts/retries.sql`
- Create: `cockroach/results/csv/retries_10wh.csv`

- [ ] **Step 5.1: Write SQL to capture retry counts**

`cockroach/scripts/retries.sql`:
```sql
SELECT
  transaction_type,
  count(*) AS txn_count,
  sum(retries) AS total_retries,
  avg(retries) AS avg_retries
FROM crdb_internal.transaction_statistics
WHERE app_name = '$ cockroach workload'
GROUP BY transaction_type;
```

- [ ] **Step 5.2: Run query and save CSV**

Run:
```bash
docker exec -i cockroach1 ./cockroach sql --insecure --host=cockroach1:26257 --format=csv < cockroach/scripts/retries.sql > cockroach/results/csv/retries_10wh.csv
```

Expected columns: `transaction_type`, `txn_count`, `total_retries`, `avg_retries`.

- [ ] **Step 5.3: Verify retries file**

Run:
```bash
cat cockroach/results/csv/retries_10wh.csv
```
Expected: CSV with rows for each transaction type; `total_retries` > 0 under concurrent load.

---

## Task 6: Scale Warehouse Count and Measure Throughput Decay (10 -> 500)

**Files:**
- Modify: `cockroach/results/csv/` (new files)

- [ ] **Step 6.1: Re-initialize schema for 500 warehouses**

Run:
```bash
cockroach workload init tpcc --warehouses 500 "postgresql://root@cockroach1:26257?sslmode=disable"
```
Expected: Longer initialization time (minutes). All 500 warehouse rows inserted.

- [ ] **Step 6.2: Run benchmarks at 10, 50, 100, 500 warehouses**

Run sequentially:
```bash
for wh in 10 50 100 500; do
  echo "=== Benchmarking $wh warehouses ==="
  ./cockroach/scripts/benchmark.sh "$wh" 5m 1m
done
```

- [ ] **Step 6.3: Extract tpmC vs warehouses into CSV**

Run:
```bash
python3 -c "
import re, glob, csv
with open('cockroach/results/csv/tpmC_scaling.csv','w',newline='') as f:
  w=csv.writer(f); w.writerow(['warehouses','tpmC','efc','avg_ms','p50_ms','p95_ms','p99_ms'])
  for path in sorted(glob.glob('cockroach/results/raw/tpcc_*wh_*.log')):
    wh=int(re.search(r'tpcc_(\d+)wh_',path).group(1))
    for line in open(path):
      m=re.search(r'\s+tpmC\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)',line)
      if m: w.writerow([wh]+list(m.groups()))
"
```
Expected: `cockroach/results/csv/tpmC_scaling.csv` with rows for each warehouse count.

---

## Task 7: Chaos Engineering — Kill Node and Measure Recovery

**Files:**
- Create: `cockroach/scripts/chaos-kill.sh`
- Create: `cockroach/results/screenshots/recovery-notes.md`

- [ ] **Step 7.1: Write chaos test script**

`cockroach/scripts/chaos-kill.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail

NODE="${1:-cockroach3}"
OUTDIR="$(dirname "$0")/../results/raw"
mkdir -p "$OUTDIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTFILE="$OUTDIR/chaos_${NODE}_${TIMESTAMP}.log"

echo "[INFO] Starting background workload before killing $NODE..."
cockroach workload run tpcc \
  --warehouses 50 --duration 10m --ramp 30s --tolerate-errors \
  "postgresql://root@cockroach1:26257?sslmode=disable" > "$OUTFILE" 2>&1 &
WORKLOAD_PID=$!
sleep 45  # ramp + steady state

echo "[INFO] Killing $NODE at $(date +%s)"
KILL_TIME=$(date +%s)
docker kill "$NODE"

echo "[INFO] Waiting for recovery (re-election + under-replicated ranges -> 0)..."
sleep 30

# Poll Admin UI or SQL for under-replicated ranges = 0
for i in {1..60}; do
  UNDER=$(docker exec cockroach1 ./cockroach sql --insecure --host=cockroach1:26257 --format=csv -e "SELECT count(*) FROM crdb_internal.ranges WHERE array_length(replicas,1) < 3;" | tail -n 1)
  if [ "$UNDER" = "0" ] || [ -z "$UNDER" ]; then
    RECOVERY_TIME=$(date +%s)
    DELTA=$((RECOVERY_TIME - KILL_TIME))
    echo "[RESULT] Node $NODE killed. Recovery time: ${DELTA}s"
    break
  fi
  sleep 1
done

# Restart the node for next test
docker start "$NODE"
echo "[INFO] Node $NODE restarted."

wait $WORKLOAD_PID || true
echo "[INFO] Workload complete. Output: $OUTFILE"
```

Make executable: `chmod +x cockroach/scripts/chaos-kill.sh`

- [ ] **Step 7.2: Execute chaos test and capture recovery time**

Run:
```bash
./cockroach/scripts/chaos-kill.sh cockroach3
```
Expected: Log prints `[RESULT] Node cockroach3 killed. Recovery time: XXs`. Save this number.

- [ ] **Step 7.3: Screen record Admin UI during fault (manual)**

Open browser to http://localhost:8080/#/metrics/cluster/sql/overview.
Start screen recording. Execute `./cockroach/scripts/chaos-kill.sh cockroach3`.
Observe:
- `Under-replicated ranges` spike then drop to 0
- `SQL Queries` may dip slightly but do not hit zero
Stop recording. Save file to `cockroach/results/screenshots/chaos-recording.mov`.

- [ ] **Step 7.4: Document recovery metrics**

`cockroach/results/screenshots/recovery-notes.md`:
```markdown
# Chaos Engineering Results: CockroachDB

## Node Kill Test
- Node killed: cockroach3
- Kill timestamp: [fill from script output]
- Recovery time: [XX] seconds
- Under-replicated ranges peak: [value]
- tpmC impact during fault: [extract from workload log]
- Success rate during fault: [extract from workload log]
```

---

## Task 8: Measure 1-Node vs 3-Node Throughput Overhead (Raft Cost)

**Files:**
- Create: `cockroach/results/csv/overhead_comparison.csv`

- [ ] **Step 8.1: Run benchmark on single node**

Modify `docker-compose.yml` temporarily or start a single-node container:
```bash
docker run -d --name cockroach-single -p 26256:26257 -p 8083:8080 cockroachdb/cockroach:latest-v24.1 start-single-node --insecure
cockroach workload init tpcc --warehouses 50 "postgresql://root@localhost:26256?sslmode=disable"
cockroach workload run tpcc --warehouses 50 --duration 5m --ramp 1m --tolerate-errors "postgresql://root@localhost:26256?sslmode=disable" | tee cockroach/results/raw/tpcc_50wh_single_node.log
```

- [ ] **Step 8.2: Calculate overhead percentage**

Run:
```bash
python3 -c "
import re

def extract_tpmC(path):
  for line in open(path):
    m=re.search(r'tpmC\s+([\d.]+)',line)
    if m: return float(m.group(1))
  return None

tpmc_1 = extract_tpmC('cockroach/results/raw/tpcc_50wh_single_node.log')
tpmc_3 = extract_tpmC('cockroach/results/raw/tpcc_50wh_*.log')  # use existing 3-node run
overhead = ((tpmc_1 - tpmc_3)/tpmc_1)*100 if tpmc_1 and tpmc_3 else 0
print(f'1-node tpmC: {tpmc_1}')
print(f'3-node tpmC: {tpmc_3}')
print(f'Raft overhead: {overhead:.2f}%')
"
```
Save result into `cockroach/results/csv/overhead_comparison.csv`.

---

## Task 9: Generate Analysis Charts and Final Report Artifacts

**Files:**
- Create: `cockroach/analysis/charts.ipynb`

- [ ] **Step 9.1: Write Jupyter notebook for charts**

`cockroach/analysis/charts.ipynb`:
```python
import pandas as pd
import matplotlib.pyplot as plt

# Load scaling data
df = pd.read_csv('../results/csv/tpmC_scaling.csv')
df = df.groupby('warehouses').mean().reset_index()

fig, ax1 = plt.subplots()
ax1.set_xlabel('Warehouses')
ax1.set_ylabel('tpmC', color='tab:blue')
ax1.plot(df['warehouses'], df['tpmC'], color='tab:blue', marker='o')
ax1.tick_params(axis='y', labelcolor='tab:blue')

ax2 = ax1.twinx()
ax2.set_ylabel('p99 Latency (ms)', color='tab:red')
ax2.plot(df['warehouses'], df['p99_ms'], color='tab:red', marker='x')
ax2.tick_params(axis='y', labelcolor='tab:red')

plt.title('CockroachDB TPC-C: Throughput vs Latency Scaling')
fig.tight_layout()
plt.savefig('../results/csv/scaling_chart.png')
plt.show()
```

- [ ] **Step 9.2: Run notebook to generate PNG**

Run:
```bash
cd cockroach/analysis
jupyter nbconvert --to notebook --execute charts.ipynb --output charts_executed.ipynb
```
Expected: `cockroach/results/csv/scaling_chart.png` created.

- [ ] **Step 9.3: Consolidate all CSV results into shared comparison template**

Manually copy values from:
- `cockroach/results/csv/tpmC_scaling.csv`
- `cockroach/results/csv/retries_10wh.csv`
- `cockroach/results/csv/overhead_comparison.csv`
- `cockroach/results/screenshots/recovery-notes.md`

into `shared/comparison-template.md`.

---

## Task 10: Cleanup and Git Commit

- [ ] **Step 10.1: Remove large raw logs from git if needed**

If raw logs are huge, add to `.gitignore`:
```bash
echo "cockroach/results/raw/*.log" >> .gitignore
echo "cockroach/results/screenshots/*.mov" >> .gitignore
```
Keep CSVs and charts in git.

- [ ] **Step 10.2: Final commit**

```bash
git add cockroach/ shared/ .gitignore
git commit -m "feat: complete CRDB TPC-C benchmark artifacts and analysis"
```

---

## Self-Review Checklist

1. **Spec coverage:**
   - [x] 3-node cluster with Raft quorum (Task 1-2)
   - [x] TPC-C benchmark via `cockroach workload` (Task 3)
   - [x] p50/p95/p99 latency per txn type (Task 4)
   - [x] Conflict retry analysis at SERIALIZABLE (Task 5)
   - [x] Chaos kill + recovery time measurement (Task 7)
   - [x] Scale warehouses 10 -> 500 and throughput decay (Task 6)
   - [x] Screen recording of Admin UI during fault (Task 7.3)
   - [x] 1-node vs 3-node overhead % (Task 8)
   - [x] Comparison charts (Task 9)
   - [x] Shared comparison template with MongoDB team (Task 1.4, 9.3)

2. **Placeholder scan:** None detected — all steps contain exact commands and expected outputs.

3. **Type consistency:** File paths and variable names consistent across tasks.
