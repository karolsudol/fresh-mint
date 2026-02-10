# 🌿 Fresh Mint ✨

Hands-on demo for learning Apache Flink and Apache Kafka streaming concepts through practical examples.

## Current Program

**StreamingJob** - Stateful message counter demonstrating:
- Real-time stream processing with Kafka source and sink
- Stateful aggregation (running count maintained in Flink state)
- Fault-tolerant checkpointing (every 10 seconds)
- KeyedStream processing with automatic state management

## Learning Programs

Additional Flink jobs to practice core streaming concepts:

- **WindowingJob** - Time-based windowing (tumbling, sliding, session windows)
- **EventTimeJob** - Event time vs processing time, watermarks, late data handling
- **StateTypesJob** - State management (ValueState, ListState, MapState, ReducingState)
- **StreamJoinJob** - Stream joins (interval join, window join)
- **IcebergSinkJob** - Long-term state persistence with Apache Iceberg (local Parquet files)

## Monitoring & Access

| Service | URL | Description |
|---------|-----|-------------|
| **Flink Dashboard** | [http://localhost:8081](http://localhost:8081) | Monitor jobs, checkpoints, metrics |
| **Kafka UI** | [http://localhost:8080](http://localhost:8080) | Browse topics and messages |
| **Kafka REST API** | [http://localhost:8082](http://localhost:8082) | HTTP interface to Kafka |
| **Kafka Broker** | `localhost:9092` | Native Kafka protocol (TCP) |

## Architecture

- **Kafka (KRaft mode)**: No Zookeeper needed (saves RAM)
- **Flink Cluster**: 1 JobManager + 1 TaskManager (1 slot)
- **StreamingJob**: Flink job that maintains stateful running count
- **Topics**:
  - `input-topic`: Raw messages from producers
  - `output-topic`: JSON results with stateful count

## Prerequisites

- Docker and Docker Compose
- Java 11
- Maven (optional, can use Docker for building)

## Quick Start

### 1. Start the Infrastructure
```bash
make up
```

### 2. Build the Project
If you have Maven installed locally:
```bash
make build
```
Otherwise, use Docker to build:
```bash
make build-docker
```

**Note**: If containers were already running when you built, restart them to pick up the JAR:
```bash
docker compose restart jobmanager taskmanager
```

### 3. Submit the Flink Job
This automatically creates topics and submits the job:
```bash
make submit-flink
```

### 4. Send Test Messages
```bash
make send-message    # Send a test message to Kafka
```

### 5. View Real-Time State Updates

**Option 1: Watch output-topic (Recommended)**
```bash
make watch-output    # See JSON state updates in real-time
```

**Option 2: Kafka UI**
- Go to [http://localhost:8080](http://localhost:8080)
- Navigate to Topics → `output-topic` → Messages
- See JSON like: `{"metric":"TotalMessages","count":5,"timestamp":"2026-02-10T12:00:00Z"}`

**Option 3: Check logs**
```bash
make check-count     # Show latest count from Flink logs
```

## Available Commands

```bash
make help            # Show all commands
make up              # Start/Create Kafka and Flink (background)
make stop            # Stop containers without removing them
make start           # Start already created/stopped containers
make down            # Stop and REMOVE containers and networks
make build           # Build the project using local Maven
make build-docker    # Build the project using Maven in Docker
make init-topics     # Create required Kafka topics
make send-message    # Send a test message to Kafka via REST API
make submit-flink    # Submit the Flink job to the cluster
make cancel-flink    # Cancel all running Flink jobs
make check-count     # Check the current message count from Flink
make watch-output    # Watch output-topic for real-time state updates
make logs            # Show docker logs
```

## Understanding the Data Flow

```
Producer → input-topic → Flink (Stateful Processing) → output-topic → Consumer
                            ↓
                      Flink State
                   (Running Count)
                            ↓
                    Checkpoints
                   (Every 10s)
```

### Kafka Concepts

**Partitions**: Topics are split into partitions for parallelism. This demo uses 1 partition per topic.

**Offsets**: Each message gets a sequential offset number (0, 1, 2, ...) within its partition. This is Kafka's way of tracking message position.

**Example**:
- Message 1 → `input-topic` partition 0, offset 0
- Message 2 → `input-topic` partition 0, offset 1
- Message 3 → `input-topic` partition 0, offset 2

### Flink Concepts

**State**: Flink maintains a running count in memory (and checkpoints to disk). Even if Flink restarts, it restores the count from the latest checkpoint.

**Checkpoints**: Automatic snapshots of state every 10 seconds. Enables fault tolerance.

**KeyBy**: Groups messages by key (`"TotalMessages"`) to enable stateful processing.

## Sending Messages via REST API

```bash
curl -X POST http://localhost:8082/topics/input-topic \
  -H "Content-Type: application/vnd.kafka.json.v2+json" \
  -d '{"records":[{"value":{"userId":"user123","action":"click"}}]}'
```

## What's Included

- **Kafka** (KRaft mode - no Zookeeper)
- **Flink** (JobManager + TaskManager, 4 slots)
- **Kafka UI** - http://localhost:8080
- **Kafka REST** - http://localhost:8082
- **Apache Iceberg** - Local Parquet files in `./iceberg-warehouse/`
- **RocksDB** - State backend

## Memory Management

The environment is limited to approximately 3.8GB of RAM total:
- Kafka: 1GB
- Kafka REST: 512MB
- Kafka UI: 768MB
- Flink JobManager: 1GB
- Flink TaskManager: 1.5GB

## Managing the Infrastructure

- **Pause (Save RAM)**: Stops containers but keeps them for quick restart.
  ```bash
  make stop
  ```
- **Resume**: Starts the containers again.
  ```bash
  make start
  ```
- **Cleanup (Remove Everything)**: Stops and removes containers/networks.
  ```bash
  make down
  ```

## Troubleshooting

### JAR file not found when submitting Flink job
If you see "JAR file does not exist", restart the Flink containers after building:
```bash
docker compose restart jobmanager taskmanager
make submit-flink
```

### JMX connection errors in Kafka UI
These are non-critical warnings. Kafka UI can't collect JMX metrics, but all core functionality works fine.

## Dependencies

- Flink 1.17.1 + Kafka connector
- Apache Iceberg (local Parquet files)
- RocksDB state backend
- Jackson JSON

## Resources

- [Flink Documentation](https://flink.apache.org/)
- [Kafka Documentation](https://kafka.apache.org/)
- [Iceberg Documentation](https://iceberg.apache.org/)
