import logging

import apache_beam as beam
from apache_beam.options.pipeline_options import PipelineOptions


def run(argv=None):
    options = PipelineOptions(argv)

    if not options.get_all_options().get("runner"):
        options = PipelineOptions(
            [
                "--runner=PortableRunner",
                "--job_endpoint=localhost:8099",
                "--environment_type=LOOPBACK",
                "--job_name=beam-flink-example",
            ]
        )

    with beam.Pipeline(options=options) as p:
        (
            p
            | "CreateNumbers" >> beam.Create([1, 2, 3, 4, 5])
            | "Square" >> beam.Map(lambda x: x * x)
            | "Print" >> beam.Map(lambda x: print(f"✨ Result: {x}"))
        )


if __name__ == "__main__":
    logging.getLogger().setLevel(logging.INFO)
    run()
