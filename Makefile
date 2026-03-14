# Makefile for Flink & Kafka Demo
# =================================

# Variables
# ---------
# JAR_FILE is located in flink-java/target relative to the root
JAR_FILE=flink-java/target/flink-kafka-demo-1.0-SNAPSHOT.jar
FLINK_JOB_OPTIONS=--detached

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
	@echo "    run-beam-wordcount - Run the Python Beam wordcount example locally."
	@echo "    run-beam-flink-example - Run a simple Beam-to-Flink bridge test (Verify environment)."
	@echo "    run-beam-tumbling - Run the Python Beam Tumbling Window job locally (DirectRunner)."
	@echo "    submit-beam-tumbling - Submit the Python Beam Tumbling Window job to Flink cluster."
	@echo ""
	@echo "  Deploy & Manage Flink Jobs:"
	@echo "    init-topics     - Create all necessary Kafka topics for the windowing jobs."
	@echo "    submit-flink-all - Submit all three windowing Flink jobs to the cluster."
	@echo "    submit-flink-tumbling - Submit only the Flink Tumbling Window job."
	@echo "    submit-flink-sliding  - Submit only the Flink Sliding Window job."
	@echo "    submit-flink-session  - Submit only the Flink Session Window job."
	@echo "    cancel-all      - Cancel all running Flink jobs."
	@echo ""
	@echo "  Monitoring & Debugging:"
	@echo "    logs            - Tail the logs of all running services."
	@echo "    logs-flink      - Show only the print output from the Flink jobs."


# Infrastructure Management
# -------------------------
.PHONY: .env
.env: config.yaml
	@echo "Generating .env from config.yaml..."
	@echo "BOOTSTRAP_SERVERS=$(shell yq '.kafka.bootstrap_servers' config.yaml)" > .env
	@echo "INPUT_TOPIC=$(INPUT_TOPIC)" >> .env
	@echo "TUMBLING_OUT=$(TUMBLING_OUT)" >> .env
	@echo "SLIDING_OUT=$(SLIDING_OUT)" >> .env
	@echo "SESSION_OUT=$(SESSION_OUT)" >> .env
	@echo "BEAM_OUT=$(BEAM_OUT)" >> .env

up: .env
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
	@echo "Building Flink Java JAR..."
	docker run --rm \
		-v "$$(pwd)/flink-java":/usr/src/mymaven \
		-v "$$(pwd)/.m2":/root/.m2 \
		-w /usr/src/mymaven \
		maven:3.9.9-eclipse-temurin-11 mvn clean package -DskipTests

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

run-beam-flink-example:
	@echo "Starting Python Beam Flink Example (Bridge test)..."
	@(cd beam-python && uv run fresh-mint flink_example)

run-beam-kafka-test: init-topics
	@echo "Starting Python Beam Kafka Test (Reading raw events)..."
	@(cd beam-python && uv run fresh-mint kafka_test \
		--runner PortableRunner \
		--job_endpoint localhost:8099 \
		--environment_type LOOPBACK \
		--streaming \
		--job_name beam-kafka-test)

run-beam-wordcount:
	@echo "Starting Python Beam WordCount example..."
	@(cd beam-python && uv run fresh-mint wordcount_example)

run-beam-tumbling:
	@echo "Starting Python Beam Tumbling Window job locally..."
	@(cd beam-python && uv run fresh-mint tumbling_window \
		--bootstrap_servers localhost:9092 \
		--expansion_service localhost:8097 \
		--environment_type LOOPBACK)

submit-beam-tumbling: init-topics
	@echo "🚀 Submitting Python Beam Tumbling Window job via Job Server (LOOPBACK)..."
	@(cd beam-python && uv run fresh-mint tumbling_window \
		--runner PortableRunner \
		--job_endpoint localhost:8099 \
		--environment_type LOOPBACK \
		--streaming \
		--job_name beam-tumbling-window-python)

# Kafka Topics from config.yaml
INPUT_TOPIC := $(shell yq '.kafka.topics.input_events' config.yaml)
TUMBLING_OUT := $(shell yq '.kafka.topics.tumbling_window_out' config.yaml)
SLIDING_OUT := $(shell yq '.kafka.topics.sliding_window_out' config.yaml)
SESSION_OUT := $(shell yq '.kafka.topics.session_window_out' config.yaml)
BEAM_OUT := $(shell yq '.kafka.topics.beam_tumbling_window_out' config.yaml)

KAFKA_TOPICS = $(INPUT_TOPIC) $(TUMBLING_OUT) $(SLIDING_OUT) $(SESSION_OUT) $(BEAM_OUT)
init-topics: .env
	@for topic in $(KAFKA_TOPICS); do \
		echo "Creating topic: $$topic"; \
		docker compose exec kafka kafka-topics --create --topic $$topic --bootstrap-server localhost:9092 --partitions 2 --replication-factor 1 --if-not-exists; \
	done

submit-flink-all: submit-flink-tumbling submit-flink-sliding submit-flink-session

submit-flink-tumbling: init-topics build
	@echo "🚀 Submitting Flink TumblingWindowJob..."
	docker compose exec jobmanager flink run $(FLINK_JOB_OPTIONS) --class org.example.flink.TumblingWindowJob /opt/flink/usrlib/$(JAR_FILE)

submit-flink-sliding: init-topics build
	@echo "🚀 Submitting Flink SlidingWindowJob..."
	docker compose exec jobmanager flink run $(FLINK_JOB_OPTIONS) --class org.example.flink.SlidingWindowJob /opt/flink/usrlib/$(JAR_FILE)

submit-flink-session: init-topics build
	@echo "🚀 Submitting Flink SessionWindowJob..."
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
