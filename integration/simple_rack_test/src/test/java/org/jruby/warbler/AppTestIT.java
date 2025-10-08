package org.jruby.warbler;

import org.junit.jupiter.api.Test;

import java.net.*;
import java.io.*;

import static org.junit.jupiter.api.Assertions.assertEquals;


/**
 * Unit test for simple App.
 */
public class AppTestIT {
    /**
     * Hit the web app and test the response
     */
    @Test
    public void testApp() throws Exception {
        assertEquals("Hello, World", contentFrom("http://localhost:8080/"));
    }

    private static String contentFrom(@SuppressWarnings("SameParameterValue") String url) throws IOException {
        URL route = new URL(url);
        StringBuilder content = new StringBuilder();
        try (BufferedReader in = new BufferedReader(new InputStreamReader(route.openStream()))) {
            while (in.ready()) {
                content.append(in.readLine());
            }
        }
        return content.toString();
    }
}
