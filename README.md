# CockroachDB TPC-C Benchmark

## Quick start (one command)

```bash
chmod +x cockroach/scripts/install-and-run.sh
./cockroach/scripts/install-and-run.sh
```

Installs Docker + Compose (if missing), starts 3-node cluster, inits TPC-C, runs benchmark 3 times.

### Options

```bash
./cockroach/scripts/install-and-run.sh --skip-install    # Docker already installed
./cockroach/scripts/install-and-run.sh --setup-only     # cluster only, no benchmark
./cockroach/scripts/install-and-run.sh --benchmark-only # benchmark only (cluster must exist)
./cockroach/scripts/install-and-run.sh --with-chaos     # + kill 1 node test
./cockroach/scripts/install-and-run.sh --runs 1         # single benchmark run
```

## Manual steps

```bash
./cockroach/scripts/setup.sh
./cockroach/scripts/benchmark.sh
./cockroach/scripts/chaos-kill.sh
```

## Config

- `cockroach/scripts/benchmark-config.env` — warehouses, max-ops, concurrency
- `shared/benchmark-protocol.md` — protocol for MongoDB team comparison

Hardware profile: **8 vCPU, 32 GB RAM**
