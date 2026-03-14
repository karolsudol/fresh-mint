import logging
import os

import apache_beam as beam
from apache_beam.io.kafka import ReadFromKafka
from apache_beam.options.pipeline_options import PipelineOptions, SetupOptions


def run(argv=None):
    # Standard PipelineOptions
    pipeline_options = PipelineOptions(argv)

    bootstrap_servers = os.environ.get("BOOTSTRAP_SERVERS", "localhost:9092")
    input_topic = os.environ.get("INPUT_TOPIC", "input-events")

    # Save main session for global imports
    pipeline_options.view_as(SetupOptions).save_main_session = True

    with beam.Pipeline(options=pipeline_options) as p:
        (
            p
            | "ReadFromKafka"
            >> ReadFromKafka(
                consumer_config={"bootstrap.servers": bootstrap_servers},
                topics=[input_topic],
                max_num_records=None,
            )
            | "ExtractPayload" >> beam.Map(lambda kv: kv[1].decode("utf-8"))
            | "PrintToConsole" >> beam.Map(lambda x: print(f"📥 Kafka Raw Event: {x}"))
        )


if __name__ == "__main__":
    logging.getLogger().setLevel(logging.INFO)
    run()
