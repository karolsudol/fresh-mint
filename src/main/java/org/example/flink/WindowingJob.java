package org.example.flink;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.flink.api.common.eventtime.WatermarkStrategy;
import org.apache.flink.api.common.serialization.SimpleStringSchema;
import org.apache.flink.api.common.typeinfo.Types;
import org.apache.flink.api.java.tuple.Tuple3;
import org.apache.flink.connector.kafka.source.KafkaSource;
import org.apache.flink.connector.kafka.source.enumerator.initializer.OffsetsInitializer;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.api.windowing.assigners.SlidingProcessingTimeWindows;
import org.apache.flink.streaming.api.windowing.assigners.TumblingProcessingTimeWindows;
import org.apache.flink.streaming.api.windowing.assigners.ProcessingTimeSessionWindows;
import org.apache.flink.streaming.api.windowing.time.Time;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * WindowingJob demonstrates three types of time-based windows in Flink:
 *
 * 1. Tumbling Windows - Fixed-size, non-overlapping windows
 * 2. Sliding Windows - Fixed-size, overlapping windows
 * 3. Session Windows - Dynamic windows based on inactivity gaps
 */
public class WindowingJob {
    private static final Logger LOG = LoggerFactory.getLogger(WindowingJob.class);
    private static final ObjectMapper objectMapper = new ObjectMapper();

    public static void main(String[] args) throws Exception {
        final StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
        env.enableCheckpointing(10000);

        String bootstrapServers = System.getenv().getOrDefault("BOOTSTRAP_SERVERS", "kafka:29092");
        LOG.info("WindowingJob connecting to Kafka at: {}", bootstrapServers);

        KafkaSource<String> source = KafkaSource.<String>builder()
                .setBootstrapServers(bootstrapServers)
                .setTopics("input-topic")
                .setGroupId("windowing-group")
                .setStartingOffsets(OffsetsInitializer.latest())
                .setValueOnlyDeserializer(new SimpleStringSchema())
                .build();

        DataStream<String> stream = env.fromSource(source, WatermarkStrategy.noWatermarks(), "Kafka Source");

        // Parse JSON and extract (userId, action, 1) tuples
        DataStream<Tuple3<String, String, Integer>> events = stream
                .map(json -> {
                    try {
                        JsonNode node = objectMapper.readTree(json);
                        String userId = node.has("userId") ? node.get("userId").asText() : "unknown";
                        String action = node.has("action") ? node.get("action").asText() : "unknown";
                        return Tuple3.of(userId, action, 1);
                    } catch (Exception e) {
                        LOG.warn("Failed to parse JSON: {}", json, e);
                        return Tuple3.of("unknown", "unknown", 1);
                    }
                })
                .returns(Types.TUPLE(Types.STRING, Types.STRING, Types.INT));

        // 1. TUMBLING WINDOWS: 10-second windows, no overlap
        // Events are grouped into distinct 10-second buckets
        // [0-10s], [10-20s], [20-30s], etc.
        events
                .keyBy(t -> "all") // Global aggregation
                .window(TumblingProcessingTimeWindows.of(Time.seconds(10)))
                .sum(2)
                .map(t -> String.format("TUMBLING [10s]: Total events = %d", t.f2))
                .print("Tumbling");

        // 2. SLIDING WINDOWS: 10-second windows, sliding every 5 seconds
        // Windows overlap, providing more frequent updates
        // [0-10s], [5-15s], [10-20s], [15-25s], etc.
        events
                .keyBy(t -> "all")
                .window(SlidingProcessingTimeWindows.of(Time.seconds(10), Time.seconds(5)))
                .sum(2)
                .map(t -> String.format("SLIDING [10s/5s]: Total events = %d", t.f2))
                .print("Sliding");

        // 3. SESSION WINDOWS: Windows per user with 30-second inactivity gap
        // Each user gets their own session window that closes after 30s of inactivity
        // Useful for tracking user sessions, shopping carts, etc.
        events
                .keyBy(t -> t.f0) // Key by userId
                .window(ProcessingTimeSessionWindows.withGap(Time.seconds(30)))
                .sum(2)
                .map(t -> String.format("SESSION [%s, gap=30s]: events = %d", t.f0, t.f2))
                .print("Session");

        env.execute("Flink Windowing Demo");
    }
}
