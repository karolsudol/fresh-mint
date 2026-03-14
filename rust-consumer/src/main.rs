use rdkafka::client::ClientContext;
use rdkafka::config::{ClientConfig, RDKafkaLogLevel};
use rdkafka::consumer::{CommitMode, Consumer, ConsumerContext, Rebalance, StreamConsumer};
use rdkafka::error::KafkaResult;
use rdkafka::message::Message;
use serde::Deserialize;
use chrono::{DateTime, Utc};
use futures::stream::StreamExt;

#[derive(Debug, Deserialize)]
struct WindowResult {
    key: String,
    value: f64,
    #[serde(rename = "windowStart")]
    window_start: DateTime<Utc>,
    #[serde(rename = "windowEnd")]
    window_end: DateTime<Utc>,
    #[serde(rename = "windowType")]
    window_type: String,
}

// A context can be used to change the behavior of producers and consumers by adding callbacks
// that will be executed by librdkafka.
// This particular context wraps a StreamConsumer and prints out information about rebalances.
struct CustomContext;

impl ClientContext for CustomContext {}

impl ConsumerContext for CustomContext {
    fn pre_rebalance(&self, rebalance: &Rebalance) {
        println!("Pre rebalance {:?}", rebalance);
    }

    fn post_rebalance(&self, rebalance: &Rebalance) {
        println!("Post rebalance {:?}", rebalance);
    }

    fn commit_callback(&self, result: KafkaResult<()>, _offsets: &rdkafka::TopicPartitionList) {
        println!("Committing offsets: {:?}", result);
    }
}

type LoggingConsumer = StreamConsumer<CustomContext>;

async fn consume(brokers: &str, group_id: &str, topics: &[&str]) {
    let context = CustomContext;

    let consumer: LoggingConsumer = ClientConfig::new()
        .set("group.id", group_id)
        .set("bootstrap.servers", brokers)
        .set("enable.partition.eof", "false")
        .set("session.timeout.ms", "6000")
        .set("enable.auto.commit", "true")
        .set_log_level(RDKafkaLogLevel::Debug)
        .create_with_context(context)
        .expect("Consumer creation failed");

    consumer
        .subscribe(topics)
        .expect("Can't subscribe to specified topics");

    println!("Subscribed to topics: {:?}", topics);
    println!("Waiting for results... (Press Ctrl+C to stop)");

    while let Some(message) = consumer.stream().next().await {
        match message {
            Err(e) => eprintln!("Kafka error: {}", e),
            Ok(m) => {
                let payload = match m.payload_view::<str>() {
                    None => "",
                    Some(Ok(s)) => s,
                    Some(Err(e)) => {
                        eprintln!("Error viewing payload: {:?}", e);
                        ""
                    }
                };
                
                println!("
--- New Result from topic: '{}' ---", m.topic());

                match serde_json::from_str::<WindowResult>(payload) {
                    Ok(result) => {
                        println!(
                            "  Type:    {}
  Key:     {}
  Value:   {:.2}
  Window:  {} -> {}",
                            result.window_type, result.key, result.value, result.window_start, result.window_end
                        );
                    }
                    Err(e) => {
                        eprintln!("Failed to deserialize message: {}", e);
                        eprintln!("Raw payload: {}", payload);
                    }
                }

                consumer.commit_message(&m, CommitMode::Async).unwrap();
            }
        };
    }
}


#[tokio::main]
async fn main() {
    let kafka_bootstrap_servers =
        std::env::var("BOOTSTRAP_SERVERS").unwrap_or_else(|_| "localhost:9092".to_string());
    let group_id = "rust-consumer-group";
    let tumbling_out = std::env::var("TUMBLING_OUT").unwrap_or_else(|_| "tumbling-window-out".to_string());
    let sliding_out = std::env::var("SLIDING_OUT").unwrap_or_else(|_| "sliding-window-out".to_string());
    let session_out = std::env::var("SESSION_OUT").unwrap_or_else(|_| "session-window-out".to_string());
    let beam_out = std::env::var("BEAM_OUT").unwrap_or_else(|_| "beam-tumbling-window-out".to_string());

    let topics = [
        tumbling_out.as_str(),
        sliding_out.as_str(),
        session_out.as_str(),
        beam_out.as_str(),
    ];
    
    println!("Starting consumer...");
    println!("Connecting to Kafka at: {}", kafka_bootstrap_servers);
    
    consume(&kafka_bootstrap_servers, group_id, &topics).await
}
