# TPC-C Comparison: CockroachDB vs MongoDB

## Benchmark Parameters
- Warehouses tested: 10, 50, 100
- Duration per run: 3 minutes (30s warmup + 2.5m steady state)

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
