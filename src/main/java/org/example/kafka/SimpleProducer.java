package org.example.kafka;

import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.common.serialization.StringSerializer;

import java.util.Properties;

public class SimpleProducer {
    public static void main(String[] args) throws InterruptedException {
        Properties props = new Properties();
        String bootstrapServers = System.getenv().getOrDefault("BOOTSTRAP_SERVERS", "localhost:9092");
        
        props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);
        props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
        props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
        props.put(ProducerConfig.ACKS_CONFIG, "all");

        KafkaProducer<String, String> producer = new KafkaProducer<>(props);

        System.out.println("Starting producer connecting to: " + bootstrapServers);
        String topic = "input-topic";
        
        try {
            for (int i = 0; i < 1000; i++) {
                String key = Integer.toString(i);
                String msg = "Hello Flink " + i;
                
                ProducerRecord<String, String> record = new ProducerRecord<>(topic, key, msg);
                
                producer.send(record, (metadata, exception) -> {
                    if (exception == null) {
                        System.out.printf("Sent message: key=%s, value=%s, partition=%d, offset=%d%n",
                                key, msg, metadata.partition(), metadata.offset());
                    } else {
                        System.err.println("Error sending message: " + exception.getMessage());
                    }
                });
                
                Thread.sleep(1000);
            }
        } finally {
            producer.close();
        }
    }
}
