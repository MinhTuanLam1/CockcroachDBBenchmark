# TPC-C Benchmark Protocol (CockroachDB vs MongoDB)

> **Gửi team MongoDB** — thống nhất trước khi chạy benchmark. Cả hai team dùng **cùng hardware** và **cùng workload params**.

---

## 1. Hardware (bắt buộc giống nhau)

| Param | Giá trị |
|-------|---------|
| CPU | **8 vCPU** |
| RAM | **32 GB** |
| OS | Ubuntu 22.04 (hoặc cùng loại) |
| Storage | SSD |
| Network | Cùng VPC / cùng máy nếu có thể |

---

## 2. Cluster topology

| | CockroachDB (NewSQL) | MongoDB (NoSQL) |
|---|---------------------|-----------------|
| Số node | **3** | **3** (Replica Set) |
| Vai trò | Raft quorum | Primary + 2 Secondary |
| Tool benchmark | `cockroach workload tpcc` | py-tpcc hoặc OLTPBench |

---

## 3. TPC-C parameters (bắt buộc giống nhau)

| Param | Giá trị | Giải thích |
|-------|---------|------------|
| **Warehouses** | **10** | Quy mô dataset (phase 1); scale 50, 100 sau |
| **Stop condition** | **max-ops = 10,000** | Dừng sau 10.000 operations (không dùng duration) |
| **Ramp (warmup)** | **30s** | Khởi động dần, **không tính** vào metric |
| **Concurrency** | **100** | 10 workers × warehouses (TPC-C chuẩn) |
| **Runs per config** | **3 lần** | Lấy **median** |
| **Init trước mỗi scale** | Có | `init tpcc --warehouses N` |

### Ví dụ lệnh CockroachDB

```bash
./cockroach/scripts/setup.sh
./cockroach/scripts/benchmark.sh
# hoặc: ./benchmark.sh 10 10000 30s 100
```

### Ví dụ tương đương MongoDB (py-tpcc)

```bash
# Thống nhất: 10 warehouses, 10000 transactions, 100 terminals, 30s warmup
python tpcc.py --warehouses 10 --terminals 100 --runTxns 10000 --warmup 30
```

*(Điều chỉnh flag theo tool thực tế — giữ đúng 4 số: 10 / 10000 / 30s / 100)*

---

## 4. Scenario so sánh (mỗi team config riêng)

### Team CockroachDB

| Case | Config | Mục đích |
|------|--------|----------|
| A — Baseline | **1 node** | Throughput không có Raft |
| B — Distributed | **3 node** | Overhead Raft + ACID |

### Team MongoDB

| Case | Config | Mục đích |
|------|--------|----------|
| A — Speed | `w: 1`, `j: false` | Tốc độ tối đa |
| B — Safety | `w: "majority"`, `j: true` | Nhất quán cao |

---

## 5. Metrics báo cáo (cùng cột)

Mỗi run, mỗi team điền:

| Metric | Mô tả |
|--------|-------|
| **tpmC** | NewOrder transactions / phút |
| **p50 / p95 / p99 latency (ms)** | Theo txn type nếu có (NewOrder, Payment…) |
| **Total errors** | Số lỗi trong run |
| **Success rate** | `(max_ops - errors) / max_ops × 100%` |
| **Elapsed time (s)** | Thời gian hoàn thành 10.000 ops |
| **Retries** (CRDB) | Serialization retry count |
| **Balance drift** (Mongo) | Nếu không dùng multi-doc transaction |

---

## 6. Chaos test protocol

| Param | Giá trị |
|-------|---------|
| Kill | **1 node** |
| Timing | Sau **45s** warmup, workload đang chạy |
| Workload lúc chaos | TPC-C, 10 warehouses, max-ops 20.000 |
| Đo | Recovery time, success rate lúc fault, downtime |

| Metric | CockroachDB | MongoDB |
|--------|-------------|---------|
| Recovery time | Under-replicated ranges → 0 | `rs.status()`, election time |
| Success rate during fault | Errors / total ops | Failed txns / total |
| Downtime | Thời gian không phục vụ được | Thời gian không có Primary |

---

## 7. Bảng kết quả (điền sau khi chạy)

### Performance — 10 warehouses, max-ops 10.000, concurrency 100

| Run | tpmC (CRDB) | p99 ms (CRDB) | tpmC (Mongo) | p99 ms (Mongo) | Errors (CRDB) | Errors (Mongo) |
|-----|-------------|---------------|--------------|----------------|---------------|----------------|
| 1 | | | | | | |
| 2 | | | | | | |
| 3 | | | | | | |
| **Median** | | | | | | |

### Consistency overhead

| Configuration | tpmC | % drop vs baseline |
|---------------|------|--------------------|
| CRDB 1-node | | — |
| CRDB 3-node | | |
| Mongo w:1 | | — |
| Mongo w:majority + j:true | | |

### Fault tolerance

| Metric | CockroachDB | MongoDB |
|--------|-------------|---------|
| Node kill → recovery (s) | | |
| Success rate during fault (%) | | |
| Downtime observed (s) | | |

---

## 8. Thống nhất nhanh (copy-paste)

```
Hardware : 8 vCPU, 32GB RAM
Workload : TPC-C
Warehouses: 10
Stop     : max-ops 10,000 (no duration)
Ramp     : 30s warmup
Concurrency: 100
Runs     : 3, report median
Metrics  : tpmC, p50/p95/p99, errors, elapsed time
Chaos    : kill 1 node after 45s warmup
```

---

*File config CockroachDB: `cockroach/scripts/benchmark-config.env`*
