use std::time::Duration;
use rdkafka::config::ClientConfig;
use rdkafka::producer::{FutureProducer, FutureRecord};
use serde::{Deserialize, Serialize};
use tokio::time::sleep;
use rand::Rng;
use chrono::{DateTime, Utc};

#[derive(Debug, Serialize, Deserialize)]
struct Event {
    id: String,
    timestamp: DateTime<Utc>,
    value: f64,
}

#[tokio::main]
async fn main() {
    let kafka_bootstrap_servers = std::env::var("BOOTSTRAP_SERVERS").unwrap_or_else(|_| "localhost:9092".to_string());
    let topic_name = "input_events";

    println!("Connecting to Kafka at: {}", kafka_bootstrap_servers);
    println!("Producing to topic: {}", topic_name);

    let producer: FutureProducer = ClientConfig::new()
        .set("bootstrap.servers", &kafka_bootstrap_servers)
        .set("message.timeout.ms", "5000")
        .create()
        .expect("Producer creation error");

    let mut rng = rand::thread_rng();
    let user_ids = ["user-a", "user-b", "user-c", "user-d"];
    let mut counter = 0;

    loop {
        let user_id = user_ids[rng.gen_range(0..user_ids.len())];
        let event = Event {
            id: user_id.to_string(),
            timestamp: Utc::now(),
            value: rng.gen_range(1.0..100.0),
        };

        let payload = serde_json::to_string(&event).expect("Failed to serialize event");

        let record = FutureRecord::to(topic_name)
            .payload(&payload)
            .key(&event.id);

        match producer.send(record, Duration::from_secs(0)).await {
            Ok(delivery) => {
                counter += 1;
                println!("(Message #{}) Sent message: key='{}', payload='{}', delivery status: {:?}", counter, &event.id, payload, delivery);
            }
            Err((e, _)) => {
                println!("Error sending message: {}", e);
            }
        }

        // Wait for a random duration between 500ms and 3s
        sleep(Duration::from_millis(rng.gen_range(500..3000))).await;
    }
}
