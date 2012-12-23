/**
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.lang.reflect.Method;
import java.net.URI;
import java.net.URISyntaxException;
import java.net.URL;
import java.net.URLClassLoader;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Enumeration;
import java.util.List;
import java.util.jar.JarEntry;
import java.util.jar.JarFile;

public class JarMain implements Runnable {
    public static final String MAIN = "/" + JarMain.class.getName().replace('.', '/') + ".class";

    final boolean debug = isDebug();
    
    protected final String[] args;
    protected final String path, jarfile;
    
    private File extractRoot;

    JarMain(String[] args) {
        this.args = args;
        URL mainClass = getClass().getResource(MAIN);
        try {
            this.path = mainClass.toURI().getSchemeSpecificPart();
        } 
        catch (URISyntaxException e) {
            throw new RuntimeException(e);
        }
        this.jarfile = this.path.replace("!" + MAIN, "").replace("file:", "");
        
        Runtime.getRuntime().addShutdownHook(new Thread(this));
    }
    
    private URL[] extractJRuby() throws Exception {
        JarFile jf = new JarFile(this.jarfile);
        List<String> jarNames = new ArrayList<String>();
        for (Enumeration<JarEntry> eje = jf.entries(); eje.hasMoreElements(); ) {
            String name = eje.nextElement().getName();
            if (name.startsWith("META-INF/lib") && name.endsWith(".jar")) {
                jarNames.add("/" + name);
            }
        }

        extractRoot = File.createTempFile("jruby", "extract");
        extractRoot.delete();
        extractRoot.mkdirs();
        
        List<URL> urls = new ArrayList<URL>();
        for (String name : jarNames) {
            urls.add(extractJar(extractRoot, name));
        }

        return (URL[]) urls.toArray(new URL[urls.size()]);
    }

    private URL extractJar(File rootDir, String jarpath) throws Exception {
        InputStream jarStream = new URI("jar", path.replace(MAIN, jarpath), null).toURL().openStream();
        String jarname = jarpath.substring(jarpath.lastIndexOf("/") + 1, jarpath.lastIndexOf("."));
        File jarFile = new File(rootDir, jarname + ".jar");
        jarFile.deleteOnExit();
        FileOutputStream outStream = new FileOutputStream(jarFile);
        try {
            byte[] buf = new byte[65536];
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

    private int launchJRuby(URL[] jars) throws Exception {
        System.setProperty("org.jruby.embed.class.path", "");
        URLClassLoader loader = new URLClassLoader(jars);
        Class scriptingContainerClass = Class.forName("org.jruby.embed.ScriptingContainer", true, loader);
        Object scriptingContainer = scriptingContainerClass.newInstance();

        Method argv = scriptingContainerClass.getDeclaredMethod("setArgv", new Class[] {String[].class});
        argv.invoke(scriptingContainer, new Object[] {args});
        Method setClassLoader = scriptingContainerClass.getDeclaredMethod("setClassLoader", new Class[] {ClassLoader.class});
        setClassLoader.invoke(scriptingContainer, new Object[] {loader});
        debug("invoking " + jarfile + " with: " + Arrays.deepToString(args));

        Method runScriptlet = scriptingContainerClass.getDeclaredMethod("runScriptlet", new Class[] {String.class});
        return ((Number) runScriptlet.invoke(scriptingContainer, new Object[] {
                    "begin\n" +
                    "require 'META-INF/init.rb'\n" +
                    "require 'META-INF/main.rb'\n" +
                    "0\n" +
                    "rescue SystemExit => e\n" +
                    "e.status\n" +
                    "end"
                })).intValue();
    }

    protected int start() throws Exception {
        URL[] u = extractJRuby();
        return launchJRuby(u);
    }

    protected void debug(String msg) {
        if (debug) {
            System.out.println(msg);
        }
    }

    protected void delete(File f) {
        if (f.isDirectory()) {
            File[] children = f.listFiles();
            for (int i = 0; i < children.length; i++) {
                delete(children[i]);
            }
        }
        f.delete();
    }
    
    public void run() {
        if ( extractRoot != null ) delete(extractRoot);
    }

    public static void main(String[] args) {
        doStart(new JarMain(args));
    }

    protected static void doStart(final JarMain main) {
        try {
            System.exit( main.start() );
        } catch (Exception e) {
            System.err.println("error: " + e.toString());
            Throwable t = e;
            while (t.getCause() != null && t.getCause() != t) {
                t = t.getCause();
            }
            if (isDebug()) {
                t.printStackTrace();
            }
            System.exit(1);
        }
    }
    
    static boolean isDebug() {
        return System.getProperty("warbler.debug") != null;
    }
    
}
