# Makefile for Flink & Kafka Demo

JAR_FILE=target/flink-kafka-demo-1.0-SNAPSHOT.jar

.PHONY: up down stop start build build-docker run-producer run-flink-local submit-flink logs help

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
	@echo "  submit-flink    - Submit the Flink job to the cluster"
	@echo "  logs            - Show docker logs"

up:
	docker compose up -d

stop:
	docker compose stop

start:
	docker compose start

down:
	docker compose down

build:
	mvn clean package -DskipTests

build-docker:
	docker run --rm -v "$$(pwd)":/usr/src/mymaven -w /usr/src/mymaven maven:3.9.6-eclipse-temurin-11 mvn clean package -DskipTests

run-producer:
	BOOTSTRAP_SERVERS=localhost:9092 java -cp $(JAR_FILE) org.example.kafka.SimpleProducer

run-flink-local:
	BOOTSTRAP_SERVERS=localhost:9092 java -cp $(JAR_FILE) org.example.flink.StreamingJob

submit-flink:
	docker compose exec jobmanager flink run /opt/flink/usrlib/flink-kafka-demo-1.0-SNAPSHOT.jar

logs:
	docker compose logs -f
