# Makefile for Flink & Kafka Demo

JAR_FILE=target/flink-kafka-demo-1.0-SNAPSHOT.jar

.PHONY: up down stop start build build-docker run-producer run-flink-local submit-flink send-message logs help

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
	@echo "  send-message    - Send a test message to Kafka via REST API"
	@echo "  submit-flink    - Submit the Flink job to the cluster"
	@echo "  logs            - Show docker logs"

init-topics:
	docker compose exec kafka kafka-topics --create --topic input-topic --bootstrap-server localhost:9092 --partitions 1 --replication-factor 1 --if-not-exists

send-message:
	@echo "Sending test message to Kafka..."
	@curl -X POST http://localhost:8082/topics/input-topic \
		-H "Content-Type: application/vnd.kafka.json.v2+json" \
		-d '{"records":[{"value":{"userId":"user123","action":"test","timestamp":"'$$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}}]}' \
		2>/dev/null | grep -o '"offset":[0-9]*' || echo "Message sent!"

up:
	docker compose up -d
	@echo "\n🚀 Services started!"
	@echo "📊 Flink Dashboard: [http://localhost:8081]"
	@echo "🔍 Kafka UI:        [http://localhost:8080]"
	@echo "🌐 Kafka REST:      [http://localhost:8082]"
	@echo "📡 Kafka Broker:    localhost:9092"

stop:
	docker compose stop

start:
	docker compose start
	@echo "\n✅ Services resumed!"
	@echo "📊 Flink Dashboard: [http://localhost:8081]"
	@echo "🔍 Kafka UI:        [http://localhost:8080]"
	@echo "🌐 Kafka REST:      [http://localhost:8082]"
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
	docker compose exec jobmanager flink run /opt/flink/usrlib/flink-kafka-demo-1.0-SNAPSHOT.jar

logs:
	docker compose logs -f
