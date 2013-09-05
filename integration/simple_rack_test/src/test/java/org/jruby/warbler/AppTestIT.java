package org.jruby.warbler;

import java.net.*;
import java.io.*;
import org.junit.Assert;
import org.junit.Test;
import org.hamcrest.Matcher;
import org.hamcrest.Matchers;

/**
 * Unit test for simple App.
 */
public class AppTestIT
{
    private static String appName = "simple_rack_test";

    /**
     * Hit the web app and test the response
     */
    @Test
    public void testApp() throws Exception
    {
        URL url = new URL("http://localhost:8080/" + appName);
        URLConnection conn = url.openConnection();
        BufferedReader in = new BufferedReader( new InputStreamReader( conn.getInputStream()));

        String inputLine;
        String content = "";

        while ((inputLine = in.readLine()) != null)
            content = inputLine;
        in.close();

        Assert.assertEquals("Hello, World", content);
    }
}
