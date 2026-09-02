package org.jruby.warbler;

import org.junit.jupiter.api.Test;

import java.net.*;
import java.io.*;

import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Unit test for simple App.
 */
public class Rails7AppTestIT {
    /**
     * Hit the web app and test the response
     */
    @Test
    public void testApp() throws Exception {
        String content = contentFrom("http://localhost:8080/posts/");
        assertTrue(content.contains("Rails7App"), () -> "expected response to contain 'Rails7App' but was: " + content);
        assertTrue(content.contains("Listing posts"), () -> "expected response to contain 'Listing posts' but was: " + content);
    }

    private static String contentFrom(String url) throws IOException {
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
