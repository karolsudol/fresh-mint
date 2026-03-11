package org.example.flink;

import org.apache.flink.api.common.eventtime.WatermarkStrategy;
import org.apache.flink.api.common.functions.AggregateFunction;
import org.apache.flink.connector.kafka.sink.KafkaRecordSerializationSchema;
import org.apache.flink.connector.kafka.sink.KafkaSink;
import org.apache.flink.connector.kafka.source.KafkaSource;
import org.apache.flink.connector.kafka.source.enumerator.initializer.OffsetsInitializer;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.api.functions.windowing.ProcessWindowFunction;
import org.apache.flink.streaming.api.windowing.assigners.TumblingEventTimeWindows;
import org.apache.flink.streaming.api.windowing.time.Time;
import org.apache.flink.streaming.api.windowing.windows.TimeWindow;
import org.apache.flink.util.Collector;

import org.example.flink.util.Event;
import org.example.flink.util.EventDeserializationSchema;
import org.example.flink.util.WindowResult;
import org.example.flink.util.WindowResultSerializationSchema;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.time.Duration;
import java.time.Instant;

/**
 * Demonstrates a tumbling window which sums event values over fixed, 10-second, non-overlapping windows.
 * This job uses Event Time, processing events based on their embedded timestamps.
 *
 * The pipeline:
 * 1. Reads JSON events from a Kafka topic ('input_events').
 * 2. Parses them into Event POJOs.
 * 3. Assigns watermarks to handle out-of-order events.
 * 4. Keys the stream by event ID.
 * 5. Applies a 10-second tumbling window.
 * 6. Aggregates the sum of event values within the window.
 * 7. Creates a WindowResult object containing the aggregation details.
 * 8. Sinks the results to a Kafka topic ('tumbling_window_out').
 * 9. (TODO) Sinks the results to an Iceberg table.
 */
public class TumblingWindowJob {
    private static final Logger LOG = LoggerFactory.getLogger(TumblingWindowJob.class);

    // Flink Job Settings
    private static final String JOB_NAME = "TumblingWindowJob";

    // Kafka Settings
    private static final String KAFKA_BOOTSTRAP_SERVERS = System.getenv().getOrDefault("BOOTSTRAP_SERVERS", "kafka:29092");
    private static final String INPUT_TOPIC = "input_events";
    private static final String OUTPUT_TOPIC = "tumbling_window_out";
    private static final String KAFKA_GROUP_ID = "tumbling-window-group";

    public static void main(String[] args) throws Exception {
        // 1. Set up the streaming execution environment
        final StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
        env.enableCheckpointing(10000); // Checkpoint every 10 seconds

        LOG.info("Connecting to Kafka at: {}", KAFKA_BOOTSTRAP_SERVERS);

        // 2. Create a Kafka Source
        KafkaSource<Event> source = KafkaSource.<Event>builder()
                .setBootstrapServers(KAFKA_BOOTSTRAP_SERVERS)
                .setTopics(INPUT_TOPIC)
                .setGroupId(KAFKA_GROUP_ID)
                .setStartingOffsets(OffsetsInitializer.latest())
                .setValueOnlyDeserializer(new EventDeserializationSchema())
                .build();

        // 3. Create a DataStream from the source, and assign Timestamps and Watermarks
        // We allow for a 2-second out-of-orderness buffer.
        DataStream<Event> events = env.fromSource(source,
                WatermarkStrategy.<Event>forBoundedOutOfOrderness(Duration.ofSeconds(2))
                        .withTimestampAssigner((event, timestamp) -> event.timestamp.toEpochMilli()),
                "Kafka Source");

        // 4. The core windowing logic
        DataStream<WindowResult> windowedSum = events
                .keyBy(event -> event.id)
                .window(TumblingEventTimeWindows.of(Time.seconds(10)))
                .aggregate(new SumAggregator(), new WindowResultProcessor());

        // 5. Create a Kafka Sink
        KafkaSink<WindowResult> kafkaSink = KafkaSink.<WindowResult>builder()
                .setBootstrapServers(KAFKA_BOOTSTRAP_SERVERS)
                .setRecordSerializer(KafkaRecordSerializationSchema.builder()
                        .setTopic(OUTPUT_TOPIC)
                        .setValueSerializationSchema(new WindowResultSerializationSchema())
                        .build()
                )
                .build();

        // 6. Sink the results to Kafka
        windowedSum.sinkTo(kafkaSink).name("Kafka Sink");
        windowedSum.print("Tumbling Window Result"); // Also print to logs for debugging

        // TODO: Add Iceberg Sink
        // FlinkSink<RowData> icebergSink = ...
        // windowedSum.map(WindowResult::toRowData).sinkTo(icebergSink);

        // 7. Execute the Flink job
        env.execute(JOB_NAME);
    }

    /**
     * An AggregateFunction that calculates the sum of the 'value' field of events.
     */
    private static class SumAggregator implements AggregateFunction<Event, Double, Double> {
        @Override
        public Double createAccumulator() {
            return 0.0;
        }

        @Override
        public Double add(Event event, Double accumulator) {
            return accumulator + event.value;
        }

        @Override
        public Double getResult(Double accumulator) {
            return accumulator;
        }

        @Override
        public Double merge(Double a, Double b) {
            return a + b;
        }
    }

    /**
     * A ProcessWindowFunction that wraps the aggregated result into a WindowResult object.
     * This provides access to the window's metadata, such as start and end times.
     */
    private static class WindowResultProcessor extends ProcessWindowFunction<Double, WindowResult, String, TimeWindow> {
        @Override
        public void process(String key, Context context, Iterable<Double> aggregates, Collector<WindowResult> out) {
            Double sum = aggregates.iterator().next(); // We know there is only one element
            Instant windowStart = Instant.ofEpochMilli(context.window().getStart());
            Instant windowEnd = Instant.ofEpochMilli(context.window().getEnd());

            out.collect(new WindowResult(key, sum, windowStart, windowEnd, "Tumbling"));
        }
    }
}
