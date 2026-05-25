# MongoDB TPC-C Benchmark Guide

> For the MongoDB (NoSQL) team — mirror of CockroachDB setup for fair comparison.

Hardware target: **8 vCPU, 32 GB RAM** (same as CockroachDB team)

---

## 1. Cluster Setup — 3-Node Replica Set

### Using Docker Compose

Create `mongodb/docker/docker-compose.yml`:

```yaml
version: '3.8'

services:
  mongo1:
    image: mongo:6
    container_name: mongo1
    hostname: mongo1
    ports:
      - "27017:27017"
    volumes:
      - mongo-data1:/data/db
    command: >
      mongod --replSet rs0 --bind_ip_all
    networks:
      - mongo-net

  mongo2:
    image: mongo:6
    container_name: mongo2
    hostname: mongo2
    ports:
      - "27018:27017"
    volumes:
      - mongo-data2:/data/db
    command: >
      mongod --replSet rs0 --bind_ip_all
    networks:
      - mongo-net

  mongo3:
    image: mongo:6
    container_name: mongo3
    hostname: mongo3
    ports:
      - "27019:27017"
    volumes:
      - mongo-data3:/data/db
    command: >
      mongod --replSet rs0 --bind_ip_all
    networks:
      - mongo-net

volumes:
  mongo-data1:
  mongo-data2:
  mongo-data3:

networks:
  mongo-net:
    driver: bridge
```

Start and initiate replica set:

```bash
cd mongodb/docker
docker compose up -d
sleep 5

# Initiate replica set
docker exec mongo1 mongosh --eval "
  rs.initiate({
    _id: 'rs0',
    members: [
      { _id: 0, host: 'mongo1:27017' },
      { _id: 1, host: 'mongo2:27017' },
      { _id: 2, host: 'mongo3:27017' }
    ]
  })
"

# Wait for PRIMARY election
sleep 10
docker exec mongo1 mongosh --eval "rs.status()"
```

---

## 2. Install py-tpcc + MongoDB Driver

```bash
# Clone py-tpcc (same repo as CockroachDB team)
git clone https://github.com/apavlo/py-tpcc.git mongodb/py-tpcc

# Install MongoDB driver
pip install pymongo
```

---

## 3. Benchmark Config

Create `mongodb/scripts/benchmark-config.env`:

```bash
# py-tpcc MongoDB settings
PYTPCC_DRIVER=mongodb
PYTPCC_HOST=mongo1
PYTPCC_PORT=27017
PYTPCC_USER=
PYTPCC_PASS=
PYTPCC_DB=tpcc

# Benchmark params — MUST match CockroachDB team
BENCHMARK_WAREHOUSES=10
BENCHMARK_MAX_OPS=10000
BENCHMARK_RAMPUP=30
BENCHMARK_CLIENTS=100

# Chaos test params
CHAOS_WAREHOUSES=10
CHAOS_MAX_OPS=20000
CHAOS_RAMPUP=30
CHAOS_CLIENTS=100
CHAOS_WARMUP_SEC=45
CHAOS_NODE=mongo3

# MongoDB URI
MONGO_URI="mongodb://mongo1:27017,mongo2:27017,mongo3:27017/?replicaSet=rs0"
```

---

## 4. Run Benchmark — Two Cases

### Case 1: Speed (`w: 1`, no journaling)

```bash
cd mongodb/py-tpcc
python tpcc.py --driver=mongodb \
  --host=mongo1 \
  --warehouses=10 \
  --max_ops=10000 \
  --clients=100 \
  --mongodb-write-concern="{w: 1, j: false}" \
  --no-load
```

### Case 2: Safety (`w: "majority"`, `j: true`)

```bash
python tpcc.py --driver=mongodb \
  --host=mongo1 \
  --warehouses=10 \
  --max_ops=10000 \
  --clients=100 \
  --mongodb-write-concern="{w: 'majority', j: true}" \
  --no-load
```

### Case 2b: Safety + Multi-document Transaction

```bash
python tpcc.py --driver=mongodb \
  --host=mongo1 \
  --warehouses=10 \
  --max_ops=10000 \
  --clients=100 \
  --mongodb-write-concern="{w: 'majority', j: true}" \
  --enable-mongodb-transactions \
  --no-load
```

**Note:** Multi-document transactions in MongoDB 4.0+ severely reduce throughput — this is the key trade-off to measure.

---

## 5. Chaos Test — Kill 1 Node

```bash
# Start workload in background
cd mongodb/py-tpcc
python tpcc.py --driver=mongodb \
  --host=mongo1 \
  --warehouses=10 \
  --max_ops=20000 \
  --clients=100 \
  --mongodb-write-concern="{w: 'majority', j: true}" \
  --no-load > chaos.log 2>&1 &

sleep 45

# Kill secondary node
docker kill mongo3

# Measure election time
docker exec mongo1 mongosh --eval "rs.status()" | grep -E "stateStr|electionTime"

# Restart node
docker start mongo3

# Check rejoin
docker exec mongo1 mongosh --eval "rs.status()" | grep -E "stateStr|health"
```

---

## 6. Verify Data After Chaos

```bash
docker exec mongo1 mongosh tpcc --eval "
  db.warehouse.find().limit(5).forEach(printjson);
  print('Order count: ' + db.orders.countDocuments());
"
```

---

## 7. Compare with CockroachDB

Fill the comparison tables in [`benchmark-protocol.md`](./benchmark-protocol.md) with your MongoDB numbers.

Key metrics to report:
- **tpmC** (NewOrder transactions per minute)
- **p50 / p95 / p99 latency** per transaction type
- **% throughput drop** between Case 1 (Speed) and Case 2 (Safety)
- **Election time** when node killed
- **Success rate** during fault

---

## Overnight Runner (tmux)

Create `mongodb/scripts/run-overnight.sh` following the same pattern as CockroachDB:

1. Setup replica set
2. Case 1 benchmark (w: 1)
3. Case 2 benchmark (w: majority, no txn)
4. Case 2b benchmark (w: majority, with txn)
5. Chaos test
6. Post-chaos verify
