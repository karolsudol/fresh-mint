# Apache Beam Python Project

This project uses the Apache Beam Python SDK (version 2.71.0+) to build data pipelines that can run on either the local `DirectRunner` or the `FlinkRunner`.

## Why Python over Go or Java?

- **Python:** Best for ML/AI integration, rapid development, and supports the newer **Beam YAML** definitions. It uses the **Portability Framework** to access Java-based I/O connectors.
- **Java:** The reference implementation. Highest performance and lowest latency. Use this if you need custom I/O or absolute performance.
- **Go:** Stable but fewer features. Good if your team is already invested in the Go ecosystem and needs compiled binaries for worker nodes.

## Running Locally (DirectRunner)

To run the sample wordcount job locally with the `DirectRunner`:

```bash
uv run python beam_job.py --output output.txt
```

## Running on Flink (FlinkRunner)

To run on a Flink cluster (e.g., the one in `docker-compose.yaml`):

1. Start your Flink cluster:
   ```bash
   docker compose up -d
   ```
2. Submit the job (using the **LOOPBACK** environment for local development):
   ```bash
   uv run python beam_job.py \
       --runner FlinkRunner \
       --flink_master localhost:8081 \
       --environment_type LOOPBACK \
       --output output.txt
   ```

Note: For production, you would typically use a Docker container for the environment (`--environment_type DOCKER`).
