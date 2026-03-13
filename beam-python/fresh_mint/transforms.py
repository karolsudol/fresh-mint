from datetime import datetime
from typing import Any

import apache_beam as beam
from apache_beam.transforms import window

from fresh_mint.models import Event, WindowResult


class ParseEvent(beam.DoFn):
    """Parses raw JSON input into Event objects."""

    def process(self, element):
        try:
            # element is a tuple (key, value) from Kafka or just a byte string
            if isinstance(element, tuple):
                _, value = element
            else:
                value = element

            event = Event.from_json(value.decode("utf-8"))
            yield event
        except Exception as e:
            print(f"Error parsing event: {e}")


class AssignTimestamps(beam.DoFn):
    """Extracts timestamp from Event and assigns it to the PCollection."""

    def process(self, element: Event):
        # Beam expects Unix timestamps in seconds
        try:
            # Handle ISO-8601: '2025-01-20T10:00:00Z'
            ts_str = element.timestamp.replace("Z", "+00:00")
            ts = datetime.fromisoformat(ts_str).timestamp()
            yield window.TimestampedValue(element, ts)
        except Exception as e:
            print(f"Error assigning timestamp: {e}")


class FormatWindowResult(beam.DoFn):
    """Wraps the aggregated sum into a WindowResult object with window metadata."""

    def __init__(self, window_type: str):
        self.window_type = window_type

    def process(self, element, window: Any = beam.DoFn.WindowParam):
        key, sum_value = element

        # Format window boundaries as ISO-8601 strings
        window_start = (
            datetime.fromtimestamp(float(window.start), tz=None).isoformat() + "Z"
        )
        window_end = (
            datetime.fromtimestamp(float(window.end), tz=None).isoformat() + "Z"
        )

        result = WindowResult(
            key=key,
            value=sum_value,
            windowStart=window_start,
            windowEnd=window_end,
            windowType=self.window_type,
        )
        yield result.to_json().encode("utf-8")
