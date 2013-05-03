/**
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

import java.io.File;
import java.io.IOException;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.net.URI;
import java.net.URISyntaxException;
import java.net.URL;
import java.net.URLClassLoader;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Enumeration;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.jar.JarEntry;
import java.util.jar.JarFile;

public class JarMain implements Runnable {
    
    static final String MAIN = "/" + JarMain.class.getName().replace('.', '/') + ".class";

    final boolean debug = isDebug();
    
    protected final String[] args;
    protected final String archive;
    private final String path;
    
    protected File extractRoot;

    protected URLClassLoader classLoader;

    JarMain(String[] args) {
        this.args = args;
        URL mainClass = getClass().getResource(MAIN);
        try {
            this.path = mainClass.toURI().getSchemeSpecificPart();
        } 
        catch (URISyntaxException e) {
            throw new RuntimeException(e);
        }
        archive = this.path.replace("!" + MAIN, "").replace("file:", "");
        
        Runtime.getRuntime().addShutdownHook(new Thread(this));
    }
    
    protected URL[] extractArchive() throws Exception {
        final JarFile jarFile = new JarFile(archive);
        try {
            Map<String, JarEntry> jarNames = new HashMap<String, JarEntry>();
            for (Enumeration<JarEntry> e = jarFile.entries(); e.hasMoreElements(); ) {
                JarEntry entry = e.nextElement();
                String extractPath = getExtractEntryPath(entry);
                if ( extractPath != null ) jarNames.put(extractPath, entry);
            }

            extractRoot = File.createTempFile("jruby", "extract");
            extractRoot.delete(); extractRoot.mkdirs();

            final List<URL> urls = new ArrayList<URL>();
            for (Map.Entry<String, JarEntry> e : jarNames.entrySet()) {
                URL entryURL = extractEntry(e.getValue(), e.getKey());
                if (entryURL != null) urls.add( entryURL );
            }
            return (URL[]) urls.toArray(new URL[urls.size()]);
        }
        finally {
            jarFile.close();
        }
    }

    protected String getExtractEntryPath(final JarEntry entry) {
        final String name = entry.getName();
        if ( name.startsWith("META-INF/lib") && name.endsWith(".jar") ) {
            return name.substring(name.lastIndexOf("/") + 1);
        }
        return null; // do not extract entry
    }
    
    protected URL extractEntry(final JarEntry entry, final String path) throws Exception {
        final File file = new File(extractRoot, path);
        if ( entry.isDirectory() ) {
            file.mkdirs(); 
            return null;
        }
        final String entryPath = entryPath(entry.getName());
        final InputStream entryStream;
        try {
            entryStream = new URI("jar", entryPath, null).toURL().openStream();
        } 
        catch (IllegalArgumentException e) {
            // TODO gems '%' file name "encoding" ?!
            debug("failed to open jar:" + entryPath + " skipping entry: " + entry.getName(), e);
            return null;
        }
        final File parent = file.getParentFile();
        if ( parent != null ) parent.mkdirs();
        FileOutputStream outStream = new FileOutputStream(file);
        final byte[] buf = new byte[65536];
        try {
            int bytesRead = 0;
            while ((bytesRead = entryStream.read(buf)) != -1) {
                outStream.write(buf, 0, bytesRead);
            }
        } 
        finally {
            entryStream.close();
            outStream.close();
            file.deleteOnExit();
        }
        if (false) debug(entry.getName() + " extracted to " + file.getPath());
        return file.toURI().toURL();
    }

    protected String entryPath(String name) {
        if ( ! name.startsWith("/") ) name = "/" + name;
        return path.replace(MAIN, name);
    }

    protected Object newScriptingContainer(final URL[] jars) throws Exception {
        System.setProperty("org.jruby.embed.class.path", "");
        classLoader = new URLClassLoader(jars);
        Class scriptingContainerClass = Class.forName("org.jruby.embed.ScriptingContainer", true, classLoader);
        Object scriptingContainer = scriptingContainerClass.newInstance();
        debug("scripting container class loader urls: " + Arrays.toString(jars));
        invokeMethod(scriptingContainer, "setArgv", (Object) args);
        invokeMethod(scriptingContainer, "setClassLoader", new Class[] { ClassLoader.class }, classLoader);
        return scriptingContainer;
    }
    
    protected int launchJRuby(final URL[] jars) throws Exception {
        final Object scriptingContainer = newScriptingContainer(jars);
        debug("invoking " + archive + " with: " + Arrays.deepToString(args));
        Object outcome = invokeMethod(scriptingContainer, "runScriptlet", launchScript());
        return ( outcome instanceof Number ) ? ( (Number) outcome ).intValue() : 0;
    }

    protected String launchScript() {
        return 
        "begin\n" +
        "  require 'META-INF/init.rb'\n" +
        "  require 'META-INF/main.rb'\n" +
        "  0\n" +
        "rescue SystemExit => e\n" +
        "  e.status\n" +
        "end";
    }
    
    protected int start() throws Exception {
        final URL[] jars = extractArchive();
        return launchJRuby(jars);
    }

    protected void debug(String msg) {
        debug(msg, null);
    }

    protected void debug(String msg, Throwable t) {
        if (debug) System.out.println(msg);
        if (debug && t != null) t.printStackTrace(System.out);
    }

    protected void warn(String msg) {
        System.out.println("WARNING: " + msg);
    }
    
    protected void delete(File f) {
        try {
          if (f.isDirectory() && !isSymlink(f)) {
              File[] children = f.listFiles();
              for (int i = 0; i < children.length; i++) {
                  delete(children[i]);
              }
          }
          f.delete();
        } catch (IOException e) {
            System.err.println("error: " + e.toString());
        }
    }

    protected boolean isSymlink(File file) throws IOException {
      if (file == null)
        throw new NullPointerException("File must not be null");
      File canon;
      if (file.getParent() == null) {
        canon = file;
      } else {
        File canonDir = file.getParentFile().getCanonicalFile();
        canon = new File(canonDir, file.getName());
      }
      return !canon.getCanonicalFile().equals(canon.getAbsoluteFile());
    }

    public void run() {
        // If the URLClassLoader isn't closed, on Windows, temp JARs won't be cleaned up
        try {
            invokeMethod(classLoader, "close");
        }
        catch(NoSuchMethodException e) { } // We're not being run on Java >= 7
        catch(Exception e) {
            System.err.println("error: " + e.toString());
        }

        if ( extractRoot != null ) delete(extractRoot);
    }

    public static void main(String[] args) {
        doStart(new JarMain(args));
    }

    protected static void doStart(final JarMain main) {
        try {
            int exit = main.start();
            if(isSystemExitEnabled()) System.exit(exit);
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
    
    protected static Object invokeMethod(final Object self, final String name, final Object... args) 
        throws NoSuchMethodException, IllegalAccessException, Exception {
        
        final Class[] signature = new Class[args.length];
        for ( int i = 0; i < args.length; i++ ) signature[i] = args[i].getClass();
        return invokeMethod(self, name, signature, args);
    }

    protected static Object invokeMethod(final Object self, final String name, final Class[] signature, final Object... args) 
        throws NoSuchMethodException, IllegalAccessException, Exception {
        Method method = self.getClass().getDeclaredMethod(name, signature);
        try {
            return method.invoke(self, args);
        }
        catch (InvocationTargetException e) {
            Throwable target = e.getTargetException();
            if (target instanceof Exception) {
                throw (Exception) target;
            }
            throw e;
        }
    }
    
    static boolean isDebug() {
        return Boolean.getBoolean("warbler.debug");
    }

    /**
     * if warbler.skip_system_exit system property is defined, we will not
     * call System.exit in the normal flow. System.exit can cause problems
     * for wrappers like procrun
     */
    private static boolean isSystemExitEnabled(){
        return System.getProperty("warbler.skip_system_exit") == null; //omission enables System.exit use
    }

}
