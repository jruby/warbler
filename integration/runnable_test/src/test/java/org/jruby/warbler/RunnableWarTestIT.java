package org.jruby.warbler;

import java.net.*;
import java.io.*;
import org.junit.Assert;
import org.junit.Test;
import org.hamcrest.Matcher;
import org.hamcrest.Matchers;

/**
 * Unit test for simple runnable war.
 */
public class RunnableWarTestIT
{
    @Test
    public void testApp() throws Exception
    {
        String testFilename = System.getProperty("testFilename");
        File f = new File(testFilename);
        Assert.assertTrue(testFilename + "should exist", f.exists());
    }
}
