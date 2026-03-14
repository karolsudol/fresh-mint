import logging
import os
import typing

import apache_beam as beam
from apache_beam.io.kafka import ReadFromKafka, WriteToKafka
from apache_beam.options.pipeline_options import PipelineOptions, SetupOptions
from apache_beam.transforms.window import FixedWindows

from fresh_mint.transforms import AssignTimestamps, FormatWindowResult, ParseEvent


def run_tumbling_window(argv=None):
    # PipelineOptions will handle all Beam/Flink flags from argv automatically
    pipeline_options = PipelineOptions(argv)

    bootstrap_servers = os.environ.get("BOOTSTRAP_SERVERS", "localhost:9092")
    input_topic = os.environ.get("INPUT_TOPIC", "input-events")
    output_topic = os.environ.get("BEAM_OUT", "beam-tumbling-window-out")

    # We use save_main_session so that worker nodes can access global imports.
    pipeline_options.view_as(SetupOptions).save_main_session = True

    with beam.Pipeline(options=pipeline_options) as p:
        # Define the pipeline steps
        input_data = p | "ReadFromKafka" >> ReadFromKafka(
            consumer_config={"bootstrap.servers": bootstrap_servers},
            topics=[input_topic],
            max_num_records=None,
            expansion_service="localhost:8097",
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
            producer_config={"bootstrap.servers": bootstrap_servers},
            topic=output_topic,
            expansion_service="localhost:8097",
        )


if __name__ == "__main__":
    logging.getLogger().setLevel(logging.INFO)
    run_tumbling_window()
