import argparse
import logging

import apache_beam as beam
from apache_beam.options.pipeline_options import PipelineOptions, SetupOptions


def run(argv=None, save_main_session=True):
    """Main entry point; defines and runs the wordcount pipeline."""
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--input", dest="input", default="sample.txt", help="Input file to process."
    )
    parser.add_argument(
        "--output",
        dest="output",
        required=True,
        help="Output file to write results to.",
    )
    known_args, pipeline_args = parser.parse_known_args(argv)

    # We use the save_main_session option because one or more DoFn's in this
    # workflow rely on global context (e.g., a module imported at module level).
    pipeline_options = PipelineOptions(pipeline_args)
    pipeline_options.view_as(SetupOptions).save_main_session = save_main_session

    # The pipeline will be run on the specified runner.
    with beam.Pipeline(options=pipeline_options) as p:
        # Read the text file[pattern] into a PCollection.
        lines = p | "Read" >> beam.io.ReadFromText(known_args.input)

        # Count the occurrences of each word.
        counts = (
            lines
            | "Split" >> (beam.FlatMap(lambda x: x.split()).with_output_types(str))
            | "PairWithOne" >> beam.Map(lambda x: (x, 1))
            | "GroupAndSum" >> beam.CombinePerKey(sum)
        )

        # Format the counts into a PCollection of strings.
        def format_result(word, count):
            return f"{word}: {count}"

        output = counts | "Format" >> beam.MapTuple(format_result)

        # Write the output using a "Write" transform that has side effects.
        output | "Write" >> beam.io.WriteToText(known_args.output)


if __name__ == "__main__":
    logging.getLogger().setLevel(logging.INFO)
    run()
