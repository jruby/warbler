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
import java.util.jar.JarFile;
import java.util.jar.JarEntry;
import java.util.List;
import java.util.ArrayList;
import java.util.Enumeration;

public class JarMain implements Runnable {
    public static final String MAIN = "/" + JarMain.class.getName().replace('.', '/') + ".class";

    private String[] args;
    private String path, jarfile;
    private boolean debug;
    private File extractRoot;

    public JarMain(String[] args) throws Exception {
        this.args = args;
        URL mainClass = getClass().getResource(MAIN);
        this.path = mainClass.toURI().getSchemeSpecificPart();
        this.jarfile = mainClass.getFile().replace("!" + MAIN, "").replace("file:", "");
        this.debug = isDebug();
        this.extractRoot = File.createTempFile("jruby", "extract");
        this.extractRoot.delete();
        this.extractRoot.mkdirs();
        Runtime.getRuntime().addShutdownHook(new Thread(this));
    }

    private URL[] extractJRuby() throws Exception {
        JarFile jf = new JarFile(this.jarfile);
        List<String> jarNames = new ArrayList<String>();
        for (Enumeration<JarEntry> eje = jf.entries(); eje.hasMoreElements(); ) {
            String name = eje.nextElement().getName();
            if (name.startsWith("META-INF/lib") && name.endsWith(".jar")) {
                jarNames.add(name);
            }
        }

        List<URL> urls = new ArrayList<URL>();
        for (String name : jarNames) {
            urls.add(extractJar(name));
        }

        return (URL[]) urls.toArray(new URL[urls.size()]);
    }

    private URL extractJar(String jarpath) throws Exception {
        InputStream jarStream = new URL("jar:" + path.replace(MAIN, jarpath)).openStream();
        String jarname = jarpath.substring(jarpath.lastIndexOf("/"), jarpath.lastIndexOf("."));
        File jarFile = File.createTempFile(jarname, ".jar");
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
        debug(jarname + ".jar extracted to " + jarFile.getPath());
        return jarFile.toURI().toURL();
    }

    private Integer launchJRuby(URL[] jars) throws Exception {
        URLClassLoader loader = new URLClassLoader(jars);
        Class scriptingContainerClass = Class.forName("org.jruby.embed.ScriptingContainer", true, loader);
        Object scriptingContainer = scriptingContainerClass.newInstance();

        Method argv = scriptingContainerClass.getDeclaredMethod("setArgv", new Class[] {String[].class});
        argv.invoke(scriptingContainer, (Object[]) args);
        Method setClassLoader = scriptingContainerClass.getDeclaredMethod("setClassLoader", new Class[] {ClassLoader.class});
        setClassLoader.invoke(scriptingContainer, new Object[] {loader});
        debug("invoking " + jarfile + " with: " + Arrays.deepToString(args));

        Method runScriptlet = scriptingContainerClass.getDeclaredMethod("runScriptlet", new Class[] {String.class});
        return (Integer) runScriptlet.invoke(scriptingContainer, new Object[] {
                "begin\n" +
                "require 'META-INF/init.rb'\n" +
                "require 'META-INF/main.rb'\n" +
                "0\n" +
                "rescue SystemExit => e\n" +
                "e.status\n" +
                "end"
            });
    }

    private int start() throws Exception {
        URL[] u = extractJRuby();
        return launchJRuby(u);
    }

    private void debug(String msg) {
        if (debug) {
            System.out.println(msg);
        }
    }

    private void delete(File f) {
        if (f.isDirectory()) {
            File[] children = f.listFiles();
            for (int i = 0; i < children.length; i++) {
                delete(children[i]);
            }
        }
        f.delete();
    }

    public void run() {
        delete(extractRoot);
    }

    public static void main(String[] args) {
        try {
            int exit = new JarMain(args).start();
            System.exit(exit);
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
