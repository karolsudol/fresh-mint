# Makefile for Flink & Kafka Demo
# =================================

# Variables
# ---------
JAR_FILE=target/flink-kafka-demo-1.0-SNAPSHOT.jar
FLINK_JOB_OPTIONS=--class-detached

# Help
# ----
.PHONY: help
help:
	@echo "Usage: make <command>"
	@echo ""
	@echo "Commands:"
	@echo "  Infrastructure Management:"
	@echo "    up              - Start Kafka and Flink cluster in the background."
	@echo "    stop            - Stop running containers without removing them."
	@echo "    start           - Resume previously stopped containers."
	@echo "    down            - Stop and REMOVE all containers, networks, and volumes."
	@echo ""
	@echo "  Build Artifacts:"
	@echo "    build           - Build the Flink jobs JAR using Maven in a Docker container."
	@echo "    build-rust      - Build both Rust applications (producer and consumer)."
	@echo ""
	@echo "  Run Applications:"
	@echo "    run-producer    - Run the Rust event producer (continuously sends data to Kafka)."
	@echo "    run-consumer    - Run the Rust window results consumer (logs Flink job output)."
	@echo ""
	@echo "  Deploy & Manage Flink Jobs:"
	@echo "    init-topics     - Create all necessary Kafka topics for the windowing jobs."
	@echo "    submit-all      - Submit all three windowing Flink jobs to the cluster."
	@echo "    submit-tumbling - Submit only the Tumbling Window job."
	@echo "    submit-sliding  - Submit only the Sliding Window job."
	@echo "    submit-session  - Submit only the Session Window job."
	@echo "    cancel-all      - Cancel all running Flink jobs."
	@echo ""
	@echo "  Monitoring & Debugging:"
	@echo "    logs            - Tail the logs of all running services."
	@echo "    logs-flink      - Show only the print output from the Flink jobs."


# Infrastructure Management
# -------------------------
up:
	docker compose up -d
	@echo "\n🚀 Services started!"
	@echo "📊 Flink Dashboard: [http://localhost:8081]"
	@echo "🔍 Kafka UI:        [http://localhost:8080]"
	@echo "📡 Kafka Broker:    localhost:9092"

stop:
	docker compose stop

start:
	docker compose start
	@echo "\n✅ Services resumed!"

down:
	docker compose down --volumes

# Build Artifacts
# ---------------
build:
	docker run --rm -v "$$(pwd)":/usr/src/mymaven -w /usr/src/mymaven maven:3.9.9-eclipse-temurin-11 mvn clean package -DskipTests

build-rust:
	@echo "Building Rust producer..."
	@(cd rust-producer && cargo build --release)
	@echo "Building Rust consumer..."
	@(cd rust-consumer && cargo build --release)

# Run Applications
# ----------------
run-producer:
	@echo "Starting Rust event producer... (Press Ctrl+C to stop)"
	@(cd rust-producer && cargo run)

run-consumer:
	@echo "Starting Rust window results consumer... (Press Ctrl+C to stop)"
	@(cd rust-consumer && cargo run)

# Deploy & Manage Flink Jobs
# --------------------------
KAFKA_TOPICS = input_events tumbling_window_out sliding_window_out session_window_out
init-topics:
	@for topic in $(KAFKA_TOPICS); do \
		echo "Creating topic: $$topic"; \
		docker compose exec kafka kafka-topics --create --topic $$topic --bootstrap-server localhost:9092 --partitions 2 --replication-factor 1 --if-not-exists; \
	done

submit-all: submit-tumbling submit-sliding submit-session

submit-tumbling: init-topics build
	@echo "🚀 Submitting TumblingWindowJob..."
	docker compose exec jobmanager flink run $(FLINK_JOB_OPTIONS) --class org.example.flink.TumblingWindowJob /opt/flink/usrlib/$(JAR_FILE)

submit-sliding: init-topics build
	@echo "🚀 Submitting SlidingWindowJob..."
	docker compose exec jobmanager flink run $(FLINK_JOB_OPTIONS) --class org.example.flink.SlidingWindowJob /opt/flink/usrlib/$(JAR_FILE)

submit-session: init-topics build
	@echo "🚀 Submitting SessionWindowJob..."
	docker compose exec jobmanager flink run $(FLINK_JOB_OPTIONS) --class org.example.flink.SessionWindowJob /opt/flink/usrlib/$(JAR_FILE)

cancel-all:
	@echo "🛑 Cancelling all running Flink jobs..."
	@docker compose exec -T jobmanager flink list -r 2>/dev/null | grep 'RUNNING' | awk '{print $$4}' | xargs -r -I {} docker compose exec -T jobmanager flink cancel {} || echo "No running jobs to cancel."

# Monitoring & Debugging
# ----------------------
logs:
	docker compose logs -f

logs-flink:
	@echo "📊 Watching Flink job results (Ctrl+C to stop)..."
	@docker compose logs -f taskmanager | grep --line-buffered -E "Window Result"
