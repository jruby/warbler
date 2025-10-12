package org.jruby.warbler;

import org.junit.jupiter.api.Test;

import java.net.*;
import java.io.*;

import static org.junit.jupiter.api.Assertions.assertTrue;


/**
 * Unit test for simple runnable war.
 */
public class RunnableWarTestIT {
    @Test
    public void testApp() {
        String testFilename = System.getProperty("testFilename");
        File f = new File(testFilename);
        assertTrue(f.exists(), testFilename + "should exist");
    }
}
