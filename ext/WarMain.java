/**
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

import java.net.URI;
import java.net.URLClassLoader;
import java.net.URL;
import java.lang.reflect.Method;
import java.io.IOException;
import java.io.InputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.util.Arrays;
import java.util.Properties;
import java.util.Map;

/**
 * Used as a Main-Class in the manifest for a .war file, so that you can run
 * a .war file with <tt>java -jar</tt>.
 *
 * WarMain can be used with different web server libraries. WarMain expects
 * to have two files present in the .war file,
 * <tt>WEB-INF/webserver.properties</tt> and <tt>WEB-INF/webserver.jar</tt>.
 *
 * When WarMain starts up, it extracts the webserver jar to a temporary
 * directory, and creates a temporary work directory for the webapp. Both
 * are deleted on exit.
 *
 * It then reads webserver.properties into a java.util.Properties object,
 * creates a URL classloader holding the jar, and loads and invokes the
 * <tt>main</tt> method of the main class mentioned in the properties.
 *
 * An example webserver.properties follows for Winstone. The <tt>args</tt>
 * property indicates the names and ordering of other properties to be used
 * as command-line arguments. The special tokens <tt>{{warfile}}</tt> and
 * <tt>{{webroot}}</tt> are substituted with the location of the .war file
 * being run and the temporary work directory, respectively.
 * <pre>
 * mainclass = winstone.Launcher
 * args = args0,args1,args2
 * args0 = --warfile={{warfile}}
 * args1 = --webroot={{webroot}}
 * args2 = --directoryListings=false
 * </pre>
 *
 * System properties can also be set via webserver.properties. For example,
 * the following entries set <tt>jetty.home</tt> before launching the server.
 * <pre>
 * props = jetty.home
 * jetty.home = {{webroot}}
 * </pre>
 */
public class WarMain implements Runnable {
    public static final String MAIN = "/" + WarMain.class.getName().replace('.', '/') + ".class";
    public static final String WEBSERVER_PROPERTIES = "/WEB-INF/webserver.properties";
    public static final String WEBSERVER_JAR = "/WEB-INF/webserver.jar";

    private String[] args;
    private String path, warfile;
    private boolean debug;
    private File webroot;

    public WarMain(String[] args) throws Exception {
        this.args = args;
        URL mainClass = getClass().getResource(MAIN);
        this.path = mainClass.toURI().getSchemeSpecificPart();
        this.warfile = this.path.replace("!" + MAIN, "").replace("file:", "");
        this.debug = isDebug();
        this.webroot = File.createTempFile("warbler", "webroot");
        this.webroot.delete();
        this.webroot.mkdirs();
        this.webroot = new File(this.webroot, new File(warfile).getName());
        debug("webroot directory is " + this.webroot.getPath());
        Runtime.getRuntime().addShutdownHook(new Thread(this));
    }

    private URL extractWebserver() throws Exception {
        InputStream jarStream = new URI("jar", path.replace(MAIN, WEBSERVER_JAR), null).toURL().openStream();
        File jarFile = File.createTempFile("webserver", ".jar");
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
        debug("webserver.jar extracted to " + jarFile.getPath());
        return jarFile.toURI().toURL();
    }

    private Properties getWebserverProperties() throws Exception {
        Properties props = new Properties();
        try {
            InputStream is = getClass().getResourceAsStream(WEBSERVER_PROPERTIES);
            props.load(is);
        } catch (Exception e) {
        }

        for (Map.Entry entry : props.entrySet()) {
            String val = (String) entry.getValue();
            val = val.replace("{{warfile}}", warfile).replace("{{webroot}}", webroot.getAbsolutePath());
            entry.setValue(val);
        }

        if (props.getProperty("props") != null) {
            String[] propsToSet = props.getProperty("props").split(",");
            for (String key : propsToSet) {
                System.setProperty(key, props.getProperty(key));
            }
        }

        return props;
    }

    private void launchWebserver(URL jar) throws Exception {
        URLClassLoader loader = new URLClassLoader(new URL[] {jar});
        Thread.currentThread().setContextClassLoader(loader);
        Properties props = getWebserverProperties();
        String mainClass = props.getProperty("mainclass");
        if (mainClass == null) {
            throw new IllegalArgumentException("unknown webserver main class ("
                                               + WEBSERVER_PROPERTIES
                                               + " is missing 'mainclass' property)");
        }
        Class klass = Class.forName(mainClass, true, loader);
        Method main = klass.getDeclaredMethod("main", new Class[] {String[].class});
        String[] newargs = launchArguments(props);
        debug("invoking webserver with: " + Arrays.deepToString(newargs));
        main.invoke(null, new Object[] {newargs});
    }

    private String[] launchArguments(Properties props) {
        String[] newargs = args;

        if (props.getProperty("args") != null) {
            String[] insertArgs = props.getProperty("args").split(",");
            newargs = new String[args.length + insertArgs.length];
            for (int i = 0; i < insertArgs.length; i++) {
                newargs[i] = props.getProperty(insertArgs[i], "");
            }
            System.arraycopy(args, 0, newargs, insertArgs.length, args.length);
        }

        return newargs;
    }

    private void start() throws Exception {
        URL u = extractWebserver();
        launchWebserver(u);
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
        delete(webroot.getParentFile());
    }

    public static void main(String[] args) {
        try {
            new WarMain(args).start();
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

