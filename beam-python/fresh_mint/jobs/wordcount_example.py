import argparse
import logging

import apache_beam as beam
from apache_beam import pvalue
from apache_beam.io.textio import ReadFromText, WriteToText
from apache_beam.options.pipeline_options import PipelineOptions, SetupOptions


def run_wordcount_example(argv=None):
    """Main entry point; defines and runs the wordcount pipeline."""
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--input", dest="input", default="sample.txt", help="Input file to process."
    )
    parser.add_argument(
        "--output",
        dest="output",
        default="output.txt",
        help="Output file to write results to.",
    )
    known_args, pipeline_args = parser.parse_known_args(argv)

    pipeline_options = PipelineOptions(pipeline_args)
    pipeline_options.view_as(SetupOptions).save_main_session = True

    with beam.Pipeline(options=pipeline_options) as p:
        # Read the text file into a PCollection.
        lines = p | "Read" >> ReadFromText(known_args.input)

        # Count the occurrences of each word.
        counts = (
            lines
            | "Split" >> (beam.FlatMap(lambda x: x.split()).with_output_types(str))
            | "PairWithOne" >> beam.Map(lambda x: (x, 1))
            | "GroupAndSum" >> beam.CombinePerKey(sum)
        )

        # 1. Write the results to file
        def format_result(word, count):
            return f"{word}: {count}"

        (
            counts
            | "Format" >> beam.MapTuple(format_result)
            | "Write" >> WriteToText(known_args.output)
        )

        # 2. Compute stats: Total Words
        total_words = (
            counts
            | "GetCounts" >> beam.Values()
            | "SumAll" >> beam.CombineGlobally(sum)
        )

        # 3. Head results: Get top 5 most common words
        top_words = counts | "Top5" >> beam.combiners.Top.Of(5, key=lambda x: x[1])

        # Print stats to console using a simple Map
        def print_stats(total, top):
            print("\n" + "=" * 40)
            print(" 📊 WORDCOUNT JOB COMPLETED")
            print("=" * 40)
            print(f" ✨ Total word count: {total}")
            print("\n 🔥 Top 5 words (Head):")
            for word, count in top:
                print(f"   - {word}: {count}")
            print("=" * 40 + "\n")

        # Combine the stats and head into a single print
        (
            p
            | "CreateDummy" >> beam.Create([None])
            | "PrintSummary"
            >> beam.Map(
                lambda _, total, top: print_stats(total, top),
                total=pvalue.AsSingleton(total_words),
                top=pvalue.AsSingleton(top_words),
            )
        )


if __name__ == "__main__":
    logging.getLogger().setLevel(logging.INFO)
    run_wordcount_example()
