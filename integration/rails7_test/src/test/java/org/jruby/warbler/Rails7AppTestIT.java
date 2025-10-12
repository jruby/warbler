package org.jruby.warbler;

import org.junit.jupiter.api.Test;

import java.net.*;
import java.io.*;

import static org.hamcrest.CoreMatchers.containsString;
import static org.hamcrest.MatcherAssert.assertThat;

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
        assertThat(content, containsString("Rails7App"));
        assertThat(content, containsString("Listing posts"));
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
