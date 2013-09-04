package org.jruby.warbler;

import java.net.*;
import java.io.*;
import junit.framework.Test;
import junit.framework.TestCase;
import junit.framework.TestSuite;

/**
 * Unit test for simple App.
 */
public class AppTestIT
    extends TestCase
{
    private static String appName = "simple_rack_test";

    /**
     * Create the test case
     *
     * @param testName name of the test case
     */
    public AppTestIT( String testName )
    {
        super( testName );
    }

    /**
     * @return the suite of tests being tested
     */
    public static Test suite()
    {
        return new TestSuite( AppTestIT.class );
    }

    /**
     * Hit the web app and test the response
     */
    public void testApp() throws Exception
    {
        URL yahoo = new URL("http://localhost:8080/" + appName);
        URLConnection yc = yahoo.openConnection();
        BufferedReader in = new BufferedReader( new InputStreamReader( yc.getInputStream()));

        String inputLine;
        String content = "";

        while ((inputLine = in.readLine()) != null)
            content = inputLine;
        in.close();

        assertEquals("Hello, World", content);
    }
}
