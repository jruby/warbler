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
        File f = new File("/Users/jkutner/test-file.tmp");
        Assert.assertTrue("test-file.tmp should exist", f.exists());
    }
}
