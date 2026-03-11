package org.example.flink.util;

import java.time.Instant;

/**
 * A POJO to represent the result of a windowed aggregation.
 * It includes the key, the aggregated value, and the window's time boundaries.
 */
public class WindowResult {

    public String key;
    public double value;
    public Instant windowStart;
    public Instant windowEnd;
    public String windowType;

    public WindowResult() {}

    public WindowResult(String key, double value, Instant windowStart, Instant windowEnd, String windowType) {
        this.key = key;
        this.value = value;
        this.windowStart = windowStart;
        this.windowEnd = windowEnd;
        this.windowType = windowType;
    }

    @Override
    public String toString() {
        return "WindowResult{" +
                "key='" + key + ''' +
                ", value=" + value +
                ", windowStart=" + windowStart +
                ", windowEnd=" + windowEnd +
                ", windowType='" + windowType + ''' +
                '}';
    }
}
