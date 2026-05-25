# TPC-C Benchmark: CockroachDB vs MongoDB

> AdvancedDB Research — VNU Thesis Benchmark Suite

## What's inside

- `cockroach/` — CockroachDB (NewSQL) scripts & configs
- `shared/` — Protocol, comparison templates, and MongoDB team guide

Hardware target: **8 vCPU, 32 GB RAM**

---

## CockroachDB — Quick start (one command)

```bash
chmod +x cockroach/scripts/*.sh
./cockroach/scripts/install-and-run.sh
```

Installs Docker + Compose (if missing), starts 3-node cluster, inits TPC-C, runs benchmark 3 times.

### Options

```bash
./cockroach/scripts/install-and-run.sh --skip-install    # Docker already installed
./cockroach/scripts/install-and-run.sh --setup-only      # cluster only, no benchmark
./cockroach/scripts/install-and-run.sh --benchmark-only  # benchmark only (cluster must exist)
./cockroach/scripts/install-and-run.sh --with-chaos    # + kill 1 node test
./cockroach/scripts/install-and-run.sh --runs 1          # single benchmark run
```

---

## Overnight runner (tmux)

Run everything sequentially and detach — come back in the morning.

```bash
./cockroach/scripts/run-overnight.sh
```

Detach: `Ctrl+B` then `D`  
Re-attach: `tmux attach -t tpcc-overnight`

Runs in order:
1. Setup cluster
2. 3× benchmark runs (10 wh, 10k ops)
3. Serializable retry verification
4. Chaos kill node + recovery
5. Post-chaos data verify
6. 1-node baseline (Raft overhead %)

---

## Manual scripts

```bash
# Infrastructure
./cockroach/scripts/setup.sh              # Start 3-node cluster + init TPC-C
./cockroach/scripts/benchmark.sh          # Run TPC-C benchmark
./cockroach/scripts/chaos-kill.sh         # Kill 1 node, measure recovery

# ACID verification
./cockroach/scripts/verify-serializable.sh    # Prove SERIALIZABLE with retry counts
./cockroach/scripts/verify-post-chaos.sh      # Verify data after node kill
./cockroach/scripts/run-baseline-1node.sh   # 1-node baseline for Raft overhead
```

---

## Config

- `cockroach/scripts/benchmark-config.env` — warehouses, max-ops, concurrency, wait flags

Current defaults:
- Warehouses: **10**
- Max-ops: **10,000**
- Concurrency: **100**
- TPC-C thinking time: **enabled** (`--wait`)

---

## MongoDB Team

See [`shared/MONGODB.md`](./shared/MONGODB.md) for the equivalent setup, benchmark, and chaos protocol.

See [`shared/benchmark-protocol.md`](./shared/benchmark-protocol.md) for unified comparison tables.
