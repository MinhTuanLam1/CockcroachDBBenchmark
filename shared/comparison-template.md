# TPC-C Comparison: CockroachDB vs MongoDB

> Full protocol: [benchmark-protocol.md](./benchmark-protocol.md)

## Benchmark Parameters
- Hardware: **8 vCPU, 32 GB RAM**
- Warehouses: **10** (phase 1); 50, 100 optional
- Stop: **max-ops 10,000** (no duration)
- Ramp: **30s** warmup
- Concurrency: **100**
- Runs: **3**, report **median**

## Performance Chart Data
| Warehouses | tpmC (CRDB) | Latency p99 (CRDB) | tpmC (Mongo) | Latency p99 (Mongo) |
|------------|-------------|--------------------|--------------|---------------------|
| 10         |             |                    |              |                     |
| 50         |             |                    |              |                     |
| 100        |             |                    |              |                     |

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
