import logging
import sys

from fresh_mint.jobs.tumbling_window import run_tumbling_window


def main():
    if len(sys.argv) < 2:
        print("Usage: fresh-mint <job_name> [args]")
        sys.exit(1)

    job_name = sys.argv[1]
    job_args = sys.argv[2:]

    if job_name == "tumbling_window":
        run_tumbling_window(job_args)
    else:
        print(f"Unknown job: {job_name}")
        sys.exit(1)


if __name__ == "__main__":
    logging.getLogger().setLevel(logging.INFO)
    main()
