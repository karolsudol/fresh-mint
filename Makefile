# Makefile for Flink & Kafka Demo

JAR_FILE=target/flink-kafka-demo-1.0-SNAPSHOT.jar

.PHONY: up down stop start build build-docker run-producer run-flink-local submit-flink cancel-flink send-message check-count watch-output logs help

help:
	@echo "Available commands:"
	@echo "  up              - Start/Create Kafka and Flink (background)"
	@echo "  stop            - Stop containers without removing them"
	@echo "  start           - Start already created/stopped containers"
	@echo "  down            - Stop and REMOVE containers and networks"
	@echo "  build           - Build the project using local Maven"
	@echo "  build-docker    - Build the project using Maven in Docker"
	@echo "  run-producer    - Run the Kafka producer locally"
	@echo "  run-flink-local - Run the Flink job locally"
	@echo "  init-topics     - Create required Kafka topics"
	@echo "  send-message    - Send a test message to Kafka via native producer"
	@echo "  submit-flink    - Submit StreamingJob to the cluster"
	@echo "  submit-windowing - Submit WindowingJob to the cluster"
	@echo "  cancel-flink    - Cancel all running Flink jobs"
	@echo "  check-count     - Check the current message count from Flink"
	@echo "  watch-output    - Watch output-topic for real-time state updates"
	@echo "  logs            - Show docker logs"

init-topics:
	docker compose exec kafka kafka-topics --create --topic input-topic --bootstrap-server localhost:9092 --partitions 1 --replication-factor 1 --if-not-exists

send-message:
	@echo "Sending test message to Kafka..."
	@echo '{"userId":"user123","action":"test","timestamp":"'$$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' | \
		docker compose exec -T kafka kafka-console-producer \
		--bootstrap-server localhost:9092 \
		--topic input-topic
	@echo "✅ Message sent!"

check-count:
	@echo "📊 Current message count from Flink:"
	@docker compose logs taskmanager 2>/dev/null | grep "Analytics Result" | tail -1 || echo "No results yet"

watch-output:
	@echo "👀 Watching output-topic for state updates (Ctrl+C to stop)..."
	@docker compose exec kafka kafka-console-consumer --bootstrap-server localhost:9092 --topic output-topic --from-beginning --property print.timestamp=true

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
	@echo "📊 Flink Dashboard: [http://localhost:8081]"
	@echo "🔍 Kafka UI:        [http://localhost:8080]"
	@echo "📡 Kafka Broker:    localhost:9092"

down:
	docker compose down

build:
	mvn clean package -DskipTests

build-docker:
	docker run --rm -v "$$(pwd)":/usr/src/mymaven -w /usr/src/mymaven maven:3.9.9-eclipse-temurin-11 mvn clean package -DskipTests

run-producer:
	BOOTSTRAP_SERVERS=localhost:9092 java -cp $(JAR_FILE) org.example.kafka.SimpleProducer

run-flink-local:
	BOOTSTRAP_SERVERS=localhost:9092 java -cp $(JAR_FILE) org.example.flink.StreamingJob

submit-flink:
	@echo "📋 Creating Kafka topics if they don't exist..."
	@docker compose exec kafka kafka-topics --create --topic input-topic --bootstrap-server localhost:9092 --partitions 1 --replication-factor 1 --if-not-exists 2>/dev/null || true
	@docker compose exec kafka kafka-topics --create --topic output-topic --bootstrap-server localhost:9092 --partitions 1 --replication-factor 1 --if-not-exists 2>/dev/null || true
	@echo "🚀 Submitting StreamingJob..."
	docker compose exec jobmanager flink run /opt/flink/usrlib/flink-kafka-demo-1.0-SNAPSHOT.jar

submit-windowing:
	@echo "📋 Creating Kafka topics if they don't exist..."
	@docker compose exec kafka kafka-topics --create --topic input-topic --bootstrap-server localhost:9092 --partitions 1 --replication-factor 1 --if-not-exists 2>/dev/null || true
	@echo "🪟 Submitting WindowingJob..."
	docker compose exec jobmanager flink run --class org.example.flink.WindowingJob /opt/flink/usrlib/flink-kafka-demo-1.0-SNAPSHOT.jar

cancel-flink:
	@echo "🛑 Cancelling all running Flink jobs..."
	@docker compose exec jobmanager flink list 2>/dev/null | grep RUNNING | awk '{print $$4}' | xargs -r -I {} docker compose exec jobmanager flink cancel {} || echo "No running jobs to cancel"

logs:
	docker compose logs -f
