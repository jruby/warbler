/**
 * Copyright (c) 2010 Engine Yard, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

import java.net.URLClassLoader;
import java.net.URL;
import java.lang.reflect.Method;
import java.io.IOException;
import java.io.InputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.util.Arrays;

public class Main {
    public static final String MAIN = "/" + Main.class.getName().replace('.', '/') + ".class";
    public static final String WINSTONE_JAR = "/WEB-INF/winstone.jar";

    private String[] args;
    private String path, warfile;
    private boolean debug;

    public Main(String[] args) throws Exception {
        this.args = args;
        URL mainClass = getClass().getResource(MAIN);
        this.path = mainClass.toURI().getSchemeSpecificPart();
        this.warfile = mainClass.getFile().replace("!" + MAIN, "").replace("file:", "");
        this.debug = isDebug();
    }

    public URL extractWinstone() throws Exception {
        InputStream jarStream = new URL("jar:" + path.replace(MAIN, WINSTONE_JAR)).openStream();
        File jarFile = File.createTempFile("winstone", ".jar");
        jarFile.deleteOnExit();
        FileOutputStream outStream = new FileOutputStream(jarFile);
        try {
            byte[] buf = new byte[4096];
            int bytesRead = 0;
            while ((bytesRead = jarStream.read(buf)) != -1) {
                outStream.write(buf, 0, bytesRead);
            }
        } finally {
            jarStream.close();
            outStream.close();
        }
        debug("winstone-lite.jar extracted to " + jarFile.getPath());
        return jarFile.toURI().toURL();
    }

    public void launchWinstone(URL jar) throws Exception {
        URLClassLoader loader = new URLClassLoader(new URL[] {jar});
        Class klass = Class.forName("winstone.Launcher", true, loader);
        Method main = klass.getDeclaredMethod("main", new Class[] {String[].class});
        String[] newargs = new String[args.length + 2];
        newargs[0] = "--warfile";
        newargs[1] = warfile;
        System.arraycopy(args, 0, newargs, 2, args.length);
        debug("invoking Winstone with: " + Arrays.deepToString(newargs));
        main.invoke(null, new Object[] {newargs});
    }

    public void run() throws Exception {
        URL u = extractWinstone();
        launchWinstone(u);
    }

    public void debug(String msg) {
        if (debug) {
            System.out.println(msg);
        }
    }

    public static void main(String[] args) {
        try {
            new Main(args).run();
        } catch (Exception e) {
            System.err.println("error: " + e.toString());
            if (isDebug()) {
                e.printStackTrace();
            }
            System.exit(1);
        }
    }

    private static boolean isDebug() {
        return System.getProperty("warbler.debug") != null;
    }
}

