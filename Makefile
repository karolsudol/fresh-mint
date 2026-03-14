# Makefile for Fresh Mint (Flink & Kafka)
# =====================================

JAR_FILE=flink-java/target/flink-kafka-demo-1.0-SNAPSHOT.jar
FLINK_JOB_OPTIONS=--detached

.PHONY: help
help:
	@echo "Usage: make <command>"
	@echo ""
	@echo "Infrastructure Management:"
	@echo "  up                   - Start all services (Kafka, Flink, Job Server, Worker Pool)"
	@echo "  down                 - Stop and remove all containers and volumes"
	@echo "  stop                 - Stop containers without removing them"
	@echo "  start                - Resume stopped containers"
	@echo ""
	@echo "Build Artifacts:"
	@echo "  build                - Build Flink Java JAR"
	@echo "  build-rust           - Build Rust producer and consumer"
	@echo ""
	@echo "Run Beam Examples (Local/Direct):"
	@echo "  run-beam-wordcount   - Run WordCount example"
	@echo ""
	@echo "Run Beam Jobs on Flink (Portable):"
	@echo "  run-beam-flink-example       - Run basic bridge test (beam-flink-example)"
	@echo "  run-beam-flink-kafka-example - Run Kafka bridge test (beam-flink-kafka-example)"
	@echo "  submit-beam-tumbling         - Submit main window job (beam-tumbling-window)"
	@echo ""
	@echo "Deploy & Manage Flink Jobs (Java):"
	@echo "  init-topics          - Create Kafka topics"
	@echo "  submit-flink-all     - Submit all Java window jobs"
	@echo "  submit-flink-tumbling - Submit Java Tumbling Window"
	@echo "  submit-flink-sliding  - Submit Java Sliding Window"
	@echo "  submit-flink-session  - Submit Java Session Window"
	@echo "  cancel-all           - Cancel all Flink jobs"
	@echo ""
	@echo "Applications & Debugging:"
	@echo "  run-producer         - Run Rust event producer"
	@echo "  run-consumer         - Run Rust result consumer"
	@echo "  logs-flink           - Watch Flink job results"

# Infrastructure
.PHONY: .env
.env: config.yaml
	@echo "Generating .env from config.yaml..."
	@echo "BOOTSTRAP_SERVERS=$(shell yq '.kafka.bootstrap_servers' config.yaml)" > .env
	@echo "INPUT_TOPIC=$(shell yq '.kafka.topics.input_events' config.yaml)" >> .env
	@echo "TUMBLING_OUT=$(shell yq '.kafka.topics.tumbling_window_out' config.yaml)" >> .env
	@echo "SLIDING_OUT=$(shell yq '.kafka.topics.sliding_window_out' config.yaml)" >> .env
	@echo "SESSION_OUT=$(shell yq '.kafka.topics.session_window_out' config.yaml)" >> .env
	@echo "BEAM_OUT=$(shell yq '.kafka.topics.beam_tumbling_window_out' config.yaml)" >> .env

up: .env
	docker compose up -d
	@echo "\n🚀 Services started! Flink: http://localhost:8081 | Kafka UI: http://localhost:8080"

down:
	docker compose down --volumes

stop:
	docker compose stop

start:
	docker compose start

# Build
build:
	docker run --rm -v "$$(pwd)/flink-java":/usr/src/mymaven -v "$$(pwd)/.m2":/root/.m2 -w /usr/src/mymaven maven:3.9.9-eclipse-temurin-11 mvn clean package -DskipTests

build-rust:
	@(cd rust-producer && cargo build --release)
	@(cd rust-consumer && cargo build --release)

# Run Applications
run-producer:
	@(cd rust-producer && cargo run)

run-consumer:
	@(cd rust-consumer && cargo run)

# Beam Jobs
run-beam-wordcount:
	@(cd beam-python && uv run fresh-mint wordcount_example)

run-beam-flink-example:
	@(cd beam-python && uv run fresh-mint flink_example \
		--runner PortableRunner \
		--job_endpoint localhost:8099 \
		--environment_type LOOPBACK \
		--job_name beam-flink-example)

run-beam-flink-kafka-example: init-topics
	@(cd beam-python && uv run fresh-mint flink_kafka_example \
		--runner PortableRunner \
		--job_endpoint localhost:8099 \
		--environment_type EXTERNAL \
		--environment_config localhost:50000 \
		--streaming \
		--job_name beam-flink-kafka-example)

submit-beam-tumbling: init-topics
	@(cd beam-python && uv run fresh-mint tumbling_window \
		--runner PortableRunner \
		--job_endpoint localhost:8099 \
		--environment_type EXTERNAL \
		--environment_config localhost:50000 \
		--streaming \
		--job_name beam-tumbling-window)

# Flink Java Jobs
init-topics: .env
	@for topic in $(shell yq '.kafka.topics[]' config.yaml); do \
		docker compose exec kafka kafka-topics --create --topic $$topic --bootstrap-server localhost:9092 --partitions 2 --replication-factor 1 --if-not-exists; \
	done

submit-flink-all: submit-flink-tumbling submit-flink-sliding submit-flink-session

submit-flink-tumbling: init-topics build
	docker compose exec jobmanager flink run $(FLINK_JOB_OPTIONS) --class org.example.flink.TumblingWindowJob /opt/flink/usrlib/$(JAR_FILE)

submit-flink-sliding: init-topics build
	docker compose exec jobmanager flink run $(FLINK_JOB_OPTIONS) --class org.example.flink.SlidingWindowJob /opt/flink/usrlib/$(JAR_FILE)

submit-flink-session: init-topics build
	docker compose exec jobmanager flink run $(FLINK_JOB_OPTIONS) --class org.example.flink.SessionWindowJob /opt/flink/usrlib/$(JAR_FILE)

cancel-all:
	@docker compose exec -T jobmanager flink list -r 2>/dev/null | grep 'RUNNING' | awk '{print $$4}' | xargs -r -I {} docker compose exec -T jobmanager flink cancel {} || echo "No jobs to cancel."

logs-flink:
	@docker compose logs -f taskmanager | grep --line-buffered -E "Window Result"
