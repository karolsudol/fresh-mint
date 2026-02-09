package org.example.kafka;

import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.common.serialization.StringSerializer;

import java.util.Properties;

public class SimpleProducer {
    public static void main(String[] args) throws InterruptedException {
        Properties props = new Properties();
        // Use localhost if running from IDE/Host. Use 'kafka' if running within Docker network.
        String bootstrapServers = System.getenv().getOrDefault("BOOTSTRAP_SERVERS", "localhost:9092");
        props.put("bootstrap.servers", bootstrapServers);
        props.put("key.serializer", StringSerializer.class.getName());
        props.put("value.serializer", StringSerializer.class.getName());

        KafkaProducer<String, String> producer = new KafkaProducer<>(props);

        System.out.println("Starting producer connecting to: " + bootstrapServers);
        
        for (int i = 0; i < 1000; i++) {
            String msg = "Hello Flink " + i;
            System.out.println("Sending: " + msg);
            producer.send(new ProducerRecord<>("input-topic", Integer.toString(i), msg));
            Thread.sleep(1000); // Send one message every second
        }

        producer.close();
    }
}
