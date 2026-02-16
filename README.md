# 🌿 Fresh Mint ✨

Hands-on demo for learning Apache Flink and Apache Kafka streaming concepts through practical, real-world examples.

## End-to-End Windowing Demo

This project demonstrates an end-to-end streaming pipeline that uses multiple Flink jobs to perform different types of windowed aggregations on a stream of events.

The pipeline consists of:
- A **Rust-based producer** that generates events and sends them to Kafka.
- **Three Flink jobs** (Tumbling, Sliding, and Session windows) that consume the events, perform aggregations, and write results back to Kafka.
- A **Rust-based consumer** that reads the final results from all jobs and prints them to the console.

### Prerequisites

- Docker and Docker Compose
- Java 11
- Rust (install via [rustup.rs](https://rustup.rs/))

### How to Run the Pipeline

**1. Start the Infrastructure**
This will bring up Kafka, the Flink cluster, and Kafka UI using Docker Compose.
```bash
make up
```
You can monitor the services at:
- **Flink Dashboard**: [http://localhost:8081](http://localhost:8081)
- **Kafka UI**: [http://localhost:8080](http://localhost:8080)

**2. Build All Artifacts**
First, build the Flink jobs JAR, then compile the two Rust applications.
```bash
make build
make build-rust
```

**3. Submit the Flink Jobs**
This command will automatically create the necessary Kafka topics and submit all three windowing jobs to the Flink cluster.
```bash
make submit-all
```
You should see `TumblingWindowJob`, `SlidingWindowJob`, and `SessionWindowJob` running in the Flink Dashboard.

**4. Run the Producer and Consumer**
Open two separate terminal windows for this step.

- **In your first terminal**, start the event producer. It will run continuously.
  ```bash
  make run-producer
  ```

- **In your second terminal**, start the results consumer.
  ```bash
  make run-consumer
  ```
  You will see the aggregated results from all three Flink jobs as they are produced, clearly marked by window type.

## Architecture

```
                                                   +-------------------------+
                               +------------------>|   TumblingWindowJob     +--+
                               |                   +-------------------------+  |
                               |                                              |
+---------------+      +----------------+      +-------------------------+  |  v
| Rust Producer +------>  input_events  +------>|    SlidingWindowJob     +--+-->+ Rust Consumer
+---------------+      +----------------+      +-------------------------+  |  ^ (Logs to console)
 (Generates      (Kafka Topic, 2 Parts.) |                                  |  |
  Random Data)                           |                   +-------------------------+  |
                               +------------------>|    SessionWindowJob     +--+
                                                   +-------------------------+
```

### Data Flow
1.  `rust-producer` generates random JSON events and sends them to the `input_events` Kafka topic.
2.  Each of the three Flink jobs (`Tumbling...`, `Sliding...`, `Session...`) independently reads from `input_events`.
3.  Each job performs its windowed aggregation and writes a `WindowResult` JSON object to its dedicated output topic (`tumbling_window_out`, `sliding_window_out`, `session_window_out`).
4.  `rust-consumer` subscribes to all three output topics and prints the results it receives.

## Flink Jobs

- **TumblingWindowJob**: Aggregates events into fixed, 10-second, non-overlapping windows.
- **SlidingWindowJob**: Aggregates events into 10-second windows that slide every 5 seconds, producing more frequent updates.
- **SessionWindowJob**: Groups events into "sessions" based on a 30-second gap of inactivity.

## Available Commands

The `Makefile` contains a full list of commands for managing the project. Run `make help` to see them all.
```bash
make help
```

## Managing the Infrastructure

- **Pause (Save RAM)**: Stops containers but keeps them for quick restart.
  ```bash
  make stop
  ```
- **Resume**: Starts the containers again.
  ```bash
  make start
  ```
- **Cleanup (Remove Everything)**: Stops and removes containers, networks, and Docker volumes (including Kafka data).
  ```bash
  make down
  ```

## Resources

- [Flink Documentation](https://flink.apache.org/)
- [Kafka Documentation](https://kafka.apache.org/)
- [Iceberg Documentation](https://iceberg.apache.org/)
