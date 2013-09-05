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
public class Rails4AppTestIT
{
    private static String appName = "rails4_test";

    /**
     * Hit the web app and test the response
     */
    @Test
    public void testApp() throws Exception
    {
        URL route = new URL("http://localhost:8080/" + appName + "/posts");
        URLConnection routeConn = route.openConnection();
        BufferedReader in = new BufferedReader( new InputStreamReader( routeConn.getInputStream()));

        String inputLine;
        String content = "";

        while ((inputLine = in.readLine()) != null)
            content += inputLine;
        in.close();

        Assert.assertThat(content, Matchers.containsString("Rails4App"));
        Assert.assertThat(content, Matchers.containsString("Listing posts"));
    }
}
