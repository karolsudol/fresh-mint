# Flink & Kafka Demo (Low Memory Profile)

This project demonstrates a simple "Hello World" integration between Apache Flink and Apache Kafka. 
It is optimized for low-memory environments.

## Monitoring & Access
- **Flink Dashboard**: [http://localhost:8081](http://localhost:8081)
- **Kafka UI**: [http://localhost:8080](http://localhost:8080) (Visualize topics and messages)
- **Kafka Broker**: [localhost:9092](localhost:9092)

## Architecture
- **Kafka (KRaft mode)**: Runs without Zookeeper to save RAM.
- **Flink Cluster**: Includes 1 JobManager and 1 TaskManager (1 slot).
- **SimpleProducer**: A Java application that sends messages to Kafka.
- **StreamingJob**: A Flink job that consumes from Kafka, transforms data to uppercase, and prints it.

## Prerequisites
- Docker and Docker Compose
- Java 11
- Maven (optional, can use Docker for building)

## Quick Start (via Makefile)

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

### 3. Submit the Flink Job
```bash
make submit-flink
```

### 4. Run the Producer
```bash
make run-producer
```

### 5. Check the Output
You can see Flink's output in the TaskManager logs:
```bash
make logs
```
Look for lines starting with `taskmanager  |`.

## Memory Management
The environment is limited to approximately 2-3GB of RAM total:
- Kafka: 1GB
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
