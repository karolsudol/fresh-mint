package org.example.flink.util;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import org.apache.flink.api.common.serialization.SerializationSchema;

public class WindowResultSerializationSchema implements SerializationSchema<WindowResult> {

    private static final long serialVersionUID = 1L;
    private static final ObjectMapper objectMapper = new ObjectMapper().registerModule(new JavaTimeModule());

    @Override
    public byte[] serialize(WindowResult element) {
        try {
            return objectMapper.writeValueAsBytes(element);
        } catch (JsonProcessingException e) {
            throw new RuntimeException("Failed to serialize WindowResult", e);
        }
    }
}
