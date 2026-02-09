package org.example.flink;

import org.apache.flink.api.common.eventtime.WatermarkStrategy;
import org.apache.flink.api.common.serialization.SimpleStringSchema;
import org.apache.flink.connector.kafka.source.KafkaSource;
import org.apache.flink.connector.kafka.source.enumerator.initializer.OffsetsInitializer;
import org.apache.flink.api.common.typeinfo.Types;
import org.apache.flink.api.java.tuple.Tuple2;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;

public class StreamingJob {

    public static void main(String[] args) throws Exception {
        final StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();

        // --- NEW: Enable Checkpointing (State Management) ---
        // Every 10 seconds a snapshot of the state is taken
        env.enableCheckpointing(10000);

        String bootstrapServers = System.getenv().getOrDefault("BOOTSTRAP_SERVERS", "kafka:29092");
        System.out.println("Flink Job connecting to Kafka at: " + bootstrapServers);

        KafkaSource<String> source = KafkaSource.<String>builder()
                .setBootstrapServers(bootstrapServers)
                .setTopics("input-topic")
                .setGroupId("flink-group")
                .setStartingOffsets(OffsetsInitializer.earliest())
                .setValueOnlyDeserializer(new SimpleStringSchema())
                .build();

        DataStream<String> stream = env.fromSource(source, WatermarkStrategy.noWatermarks(), "Kafka Source");

        // --- NEW: Stateful Analytics (Running Count) ---
        stream
              .map(s -> Tuple2.of("TotalMessages", 1))
              .returns(Types.TUPLE(Types.STRING, Types.INT))
              .keyBy(value -> value.f0) // Group by the word "TotalMessages"
              .sum(1)                   // Automatically maintains a running sum in Flink State
              .print();

        env.execute("Stateful Flink Analytics Demo");
    }
}
