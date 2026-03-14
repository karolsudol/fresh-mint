import logging
import sys

from fresh_mint.jobs.flink_example import run as run_flink_example
from fresh_mint.jobs.kafka_test import run as run_kafka_test
from fresh_mint.jobs.tumbling_window import run_tumbling_window
from fresh_mint.jobs.wordcount_example import run_wordcount_example


def main():
    if len(sys.argv) < 2:
        print("Usage: fresh-mint <job_name> [args]")
        print("Available jobs:")
        print("  - flink_example")
        print("  - kafka_test")
        print("  - tumbling_window")
        print("  - wordcount_example")
        sys.exit(1)

    job_name = sys.argv[1]
    job_args = sys.argv[2:]

    if job_name == "flink_example":
        run_flink_example(job_args)
    elif job_name == "kafka_test":
        run_kafka_test(job_args)
    elif job_name == "tumbling_window":
        run_tumbling_window(job_args)
    elif job_name == "wordcount_example":
        run_wordcount_example(job_args)
    else:
        print(f"Unknown job: {job_name}")
        sys.exit(1)


if __name__ == "__main__":
    logging.getLogger().setLevel(logging.INFO)
    main()
