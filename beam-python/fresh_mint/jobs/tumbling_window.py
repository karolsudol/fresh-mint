import argparse
import logging
import os
import typing

import apache_beam as beam
from apache_beam.io.kafka import ReadFromKafka, WriteToKafka
from apache_beam.options.pipeline_options import PipelineOptions, SetupOptions
from apache_beam.transforms.window import FixedWindows

from fresh_mint.transforms import AssignTimestamps, FormatWindowResult, ParseEvent


def run_tumbling_window(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--bootstrap_servers", default="localhost:9092", help="Kafka bootstrap servers"
    )
    parser.add_argument(
        "--input_topic",
        default=os.environ.get("INPUT_TOPIC", "input-events"),
        help="Kafka topic to read from",
    )
    parser.add_argument(
        "--output_topic",
        default=os.environ.get("BEAM_OUT", "beam-tumbling-window-out"),
        help="Kafka topic to write results to",
    )

    known_args, pipeline_args = parser.parse_known_args(argv)
    pipeline_options = PipelineOptions(pipeline_args)

    # Force LOOPBACK for local portability to avoid searching for 'docker'
    from apache_beam.options.pipeline_options import PortableOptions

    portable_options = pipeline_options.view_as(PortableOptions)
    portable_options.environment_type = "LOOPBACK"

    # We use save_main_session so that worker nodes can access global imports.
    pipeline_options.view_as(SetupOptions).save_main_session = True

    with beam.Pipeline(options=pipeline_options) as p:
        # Define the pipeline steps
        input_data = p | "ReadFromKafka" >> ReadFromKafka(
            consumer_config={"bootstrap.servers": known_args.bootstrap_servers},
            topics=[known_args.input_topic],
            max_num_records=None,
        )

        parsed_events = (
            input_data
            | "ExtractValues" >> beam.Map(lambda kv: kv[1])
            | "ParseJSON" >> beam.ParDo(ParseEvent())
            | "LogEvent"
            >> beam.Map(lambda e: logging.info(f"✨ Processed event: {e.id}") or e)
            | "AssignTimestamps" >> beam.ParDo(AssignTimestamps())
        )

        windowed_counts = (
            parsed_events
            | "TumblingWindow" >> beam.WindowInto(FixedWindows(10))
            | "KeyById" >> beam.Map(lambda event: (event.id, event.value))
            | "SumValues" >> beam.CombinePerKey(sum)
        )

        formatted_results = windowed_counts | "FormatResult" >> beam.ParDo(
            FormatWindowResult(window_type="Beam-Tumbling")
        ).with_output_types(typing.Tuple[bytes, bytes])

        formatted_results | "WriteToKafka" >> WriteToKafka(
            producer_config={"bootstrap.servers": known_args.bootstrap_servers},
            topic=known_args.output_topic,
        )


if __name__ == "__main__":
    logging.getLogger().setLevel(logging.INFO)
    run_tumbling_window()
