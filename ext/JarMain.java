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
import java.io.PrintStream;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.net.URI;
import java.net.URISyntaxException;
import java.net.URL;
import java.net.URLClassLoader;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.attribute.BasicFileAttributes;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Enumeration;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.jar.JarEntry;
import java.util.jar.JarFile;


/**
 *
 *  rrolland - I have been manually building using:
 *  javac -Xlint:unchecked -cp ./jruby-core-1.7.20.jar:bytelist-1.0.13.jar:jnr-posix-3.0.12.jar -source 1.7 -target 1.7 -d ./build ./ext/*.java
 *  cd build
 *  jar cvf warbler_jar.jar *
 *  cp ./warbler_jar.jar ../lib/
 *
 *  The maven prepare-package phase was not working for me. Failing with a:
 *  maven-plugin:1.0.10:initialize failed: Java returned: 1
 *
 *  The changes introduced here are to resolve two issues:
 *  1) Decompressing the same jar every time
 *  2) Incomplete cleanup of temp resources, i.e. jar files were not getting deleted and introducing a 25MB hit to the file system on every run. Our
 *  application runs a small process every 15min so that was not acceptable.
 *
 *  This implementation uses the timestamp of the last modified time of the executing war (or jar) to create a temp directory that is then reused until a new
 *  version of the war (or jar) is baked which causes a new last modified timestamp and a new temp directory to be used.
 *
 *  I found this class very difficult to work on because a lot of the logic relies on executing within the context of the jar that you are trying to
 *  extract the resources out of.
 *
 *  Testing for this change was done on a windows 2012 server running Java 1.8. I suspect this works on linux platforms but some additional testing
 *  would be needed. OS specific call outs for lastModifiedTime and java.io.tmpdir should be confirmed to be appropriate when testing on linux.
 *
 *
 */
public class JarMain {

    static final String MAIN = '/' + JarMain.class.getName().replace('.', '/') + ".class";

    protected final String[] args;
    protected final String archive;
    private final String path;

    protected File extractRoot;

    protected URLClassLoader classLoader;

    JarMain(String[] args) {
      this(args, null);
    }

    JarMain(String[] args, String overrideJarPath) {
        this.args = args;
        URL mainClass = getClass().getResource(MAIN);
        try {
            this.path = mainClass.toURI().getSchemeSpecificPart();
        }
        catch (URISyntaxException e) {
            throw new RuntimeException(e);
        }
        if(overrideJarPath != null) {
          archive = overrideJarPath;
        } else {
          archive = this.path.replace("!" + MAIN, "").replace("file:", "");
        }
    }

    private String getJarLastModifiedTimestamp() throws IOException {
      debug("Using archive:"+archive);
      File file = new File(archive);
      Path path = Paths.get(file.getAbsolutePath());
      BasicFileAttributes attr;
      attr = Files.readAttributes(path, BasicFileAttributes.class);
      long millis = attr.lastModifiedTime().toMillis();
      return Long.toString(millis);
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

            String rootTemp = System.getProperty("java.io.tmpdir");
            File fileToGetName = new File(archive);
            String workingPath = rootTemp+File.separator+fileToGetName.getName().replace(".", "_")+getJarLastModifiedTimestamp();
            debug("Using Working Path:"+workingPath);
            extractRoot = new File(workingPath);
            final List<URL> urls = new ArrayList<URL>(jarNames.size());

            if(extractRoot.exists()) {
              ArrayList<File> files = new ArrayList<File>();
              listf(extractRoot.getAbsolutePath(),files);
              for(File file : files){
                if(file.isFile()){
                  urls.add(file.toURI().toURL());
                }
              }
            } else {
              extractRoot.mkdirs();
              for (Map.Entry<String, JarEntry> e : jarNames.entrySet()) {
                  URL entryURL = extractEntry(e.getValue(), e.getKey());
                  if (entryURL != null) urls.add( entryURL );
              }
            }


            return urls.toArray(new URL[urls.size()]);
        } catch(Exception e) {
          e.printStackTrace();
          throw e;
        }
        finally {
            jarFile.close();
        }
    }

    private void listf(String directoryName, ArrayList<File> files) {
      File directory = new File(directoryName);

      // get all the files from a directory
      File[] fList = directory.listFiles();
      for (File file : fList) {
        String fileName = file.getName();
        String fileExtension = getExtension(fileName);
        fileExtension = fileExtension.toLowerCase();
        if (file.isFile() && fileExtension.equals("jar")) {
          files.add(file);
        } else if (file.isDirectory()) {
          listf(file.getAbsolutePath(), files);
        }
      }
    }

    protected String getExtractEntryPath(final JarEntry entry) {
        final String name = entry.getName();
        debug(name);
        if ( name.startsWith("META-INF/lib") && name.endsWith(".jar") ) {
            return name.substring(name.lastIndexOf('/') + 1);
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
          URL url = new URI("jar", entryPath, null).toURL();
          entryStream = url.openStream();
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
            int bytesRead;
            while ((bytesRead = entryStream.read(buf)) != -1) {
                outStream.write(buf, 0, bytesRead);
            }
        }
        finally {
            entryStream.close();
            outStream.close();
        }
        // if (false) debug(entry.getName() + " extracted to " + file.getPath());
        return file.toURI().toURL();
    }

    protected String entryPath(String name) {
        if ( ! name.startsWith("/") ) name = "/" + name;
        return path.replace(MAIN, name);
    }

    protected Object newScriptingContainer(final URL[] jars) throws Exception {
        setSystemProperty("org.jruby.embed.class.path", "");
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

        debug("JARS TO LOAD START ===============================================================================");
        for(URL jar : jars) {
          debug(jar.toString());
        }
        debug("JARS TO LOAD END ===============================================================================");

        return launchJRuby(jars);
    }

    protected void debug(String msg) {
        debug(msg, null);
    }

    protected void debug(String msg, Throwable t) {
        if ( isDebug() ) debug(msg);
        if ( isDebug() && t != null ) t.printStackTrace(System.out);
    }

    protected static void debug(Throwable t) {
        debug(t, System.out);
    }

    private static void debug(Throwable t, PrintStream out) {
        if ( isDebug() ) t.printStackTrace(out);
    }

    protected void warn(String msg) {
        debug("WARNING: " + msg);
    }

    protected static void error(Throwable t) {
        error(t.toString(), t);
    }

    protected static void error(String msg, Throwable t) {
        System.err.println("ERROR: " + msg);
        debug(t, System.err);
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
        }
        catch (IOException e) { error(e); }
    }

    protected boolean isSymlink(File file) throws IOException {
        if (file == null) throw new NullPointerException("File must not be null");
        final File canonical;
        if ( file.getParent() == null ) canonical = file;
        else {
            File parentDir = file.getParentFile().getCanonicalFile();
            canonical = new File(parentDir, file.getName());
        }
        return ! canonical.getCanonicalFile().equals( canonical.getAbsoluteFile() );
    }

    public static void main(String[] args) {
      main(args,null);
    }

    public static void main(String[] args,String overridePath) {
        doStart(new JarMain(args,overridePath));
    }

    protected static void doStart(final JarMain main) {
        int exit;
        try {
            exit = main.start();
        } catch (Exception e) {
            Throwable t = e;
            while ( t.getCause() != null && t.getCause() != t ) {
                t = t.getCause();
            }
            error(e.toString(), t);
            exit = 1;
        }
        try {
            if ( isSystemExitEnabled() ) System.exit(exit);
        }
        catch (SecurityException e) {
            debug(e);
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

    private static final boolean debug;
    static {
        debug = Boolean.parseBoolean( getSystemProperty("warbler.debug", "false") );
    }

    static boolean isDebug() { return debug; }

    /**
     * if warbler.skip_system_exit system property is defined, we will not
     * call System.exit in the normal flow. System.exit can cause problems
     * for wrappers like procrun
     */
    private static boolean isSystemExitEnabled(){
        return getSystemProperty("warbler.skip_system_exit") == null; //omission enables System.exit use
    }

    static String getSystemProperty(final String name) {
        return getSystemProperty(name, null);
    }

    static String getSystemProperty(final String name, final String defaultValue) {
        try {
            return System.getProperty(name, defaultValue);
        }
        catch (SecurityException e) {
            return defaultValue;
        }
    }

    static boolean setSystemProperty(final String name, final String value) {
        try {
            System.setProperty(name, value);
            return true;
        }
        catch (SecurityException e) {
            return false;
        }
    }

    static String getENV(final String name) {
        return getENV(name, null);
    }

    static String getENV(final String name, final String defaultValue) {
        try {
            if ( System.getenv().containsKey(name) ) {
                return System.getenv().get(name);
            }
            return defaultValue;
        }
        catch (SecurityException e) {
            return defaultValue;
        }
    }


    /**
     * Borrowed Methods from apache.commons.io FilenameUtils:
     * http://commons.apache.org/proper/commons-io/javadocs/api-2.5/src-html/org/apache/commons/io/FilenameUtils.html
     *
     * Avoiding introducing library dependency since these classes are virtually standalone and difficult enough to get running embedded in
     * warbler environment.
     */
    private static final char EXTENSION_SEPARATOR = '.';
    private static final int NOT_FOUND = -1;
    private static final char UNIX_SEPARATOR = '/';
    private static final char WINDOWS_SEPARATOR = '\\';

    private String getExtension(final String filename) {
      if (filename == null) {
        return null;
      }
      final int index = indexOfExtension(filename);
      if (index == NOT_FOUND) {
        return "";
      } else {
        return filename.substring(index + 1);
      }
    }

    private int indexOfExtension(final String filename) {
      if (filename == null) {
        return NOT_FOUND;
      }
      final int extensionPos = filename.lastIndexOf(EXTENSION_SEPARATOR);
      final int lastSeparator = indexOfLastSeparator(filename);
      return lastSeparator > extensionPos ? NOT_FOUND : extensionPos;
    }

    private int indexOfLastSeparator(final String filename) {
      if (filename == null) {
        return NOT_FOUND;
      }
      final int lastUnixPos = filename.lastIndexOf(UNIX_SEPARATOR);
      final int lastWindowsPos = filename.lastIndexOf(WINDOWS_SEPARATOR);
      return Math.max(lastUnixPos, lastWindowsPos);
    }

}
