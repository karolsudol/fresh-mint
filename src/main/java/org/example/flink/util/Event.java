package org.example.flink.util;

import java.time.Instant;

/**
 * A simple Plain Old Java Object (POJO) representing an event.
 * It has a public no-argument constructor and public fields, which Flink can handle efficiently.
 */
public class Event {

    public String id;
    public Instant timestamp;
    public double value;

    // Public no-argument constructor is required by Flink's POJO type system
    public Event() {}

    public Event(String id, Instant timestamp, double value) {
        this.id = id;
        this.timestamp = timestamp;
        this.value = value;
    }

    /**
     * Creates a new Event with the current timestamp.
     */
    public static Event from(String id, double value) {
        return new Event(id, Instant.now(), value);
    }

    @Override
    public String toString() {
        return "Event{" +
                "id='" + id + ''' +
                ", timestamp=" + timestamp +
                ", value=" + value +
                '}';
    }
}
