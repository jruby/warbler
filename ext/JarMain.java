/**
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

import java.io.Closeable;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.PrintStream;
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
import java.util.Objects;
import java.util.concurrent.Callable;
import java.util.jar.JarEntry;
import java.util.jar.JarFile;

public class JarMain implements Closeable {

    static final String MAIN = '/' + JarMain.class.getName().replace('.', '/') + ".class";

    protected final String[] args;
    protected final String archive;
    private final String path;

    protected File extractRoot;
    final List<Closeable> closeables = new ArrayList<>();

    JarMain(String[] args) {
        this.args = args;
        URL mainClass = Objects.requireNonNull(getClass().getResource(MAIN), MAIN + " not found!");
        URI uri;
        String pathWithoutMain;

        try {
            this.path = mainClass.toURI().getSchemeSpecificPart();
            pathWithoutMain = mainClass.toURI().getRawSchemeSpecificPart().replace("!" + MAIN, "");
            uri = new URI(pathWithoutMain);
        } catch (URISyntaxException e) {
            throw new RuntimeException(e);
        }

        archive = new File(uri.getPath()).getAbsolutePath();

        Runtime.getRuntime().addShutdownHook(new Thread(this::close, "Warbler-Shutdown"));
    }

    protected URL[] extractArchive() throws Exception {
        try (JarFile jarFile = new JarFile(archive)) {
            Map<String, JarEntry> jarNames = new HashMap<>();
            for (Enumeration<JarEntry> e = jarFile.entries(); e.hasMoreElements(); ) {
                JarEntry entry = e.nextElement();
                String extractPath = getExtractEntryPath(entry);
                if (extractPath != null) jarNames.put(extractPath, entry);
            }

            extractRoot = File.createTempFile("jruby", "extract");
            extractRoot.delete();
            extractRoot.mkdirs();
            closeables.add(() -> deleteAll(extractRoot));

            final List<URL> urls = new ArrayList<>(jarNames.size());
            for (Map.Entry<String, JarEntry> e : jarNames.entrySet()) {
                URL entryURL = extractEntry(e.getValue(), e.getKey());
                if (entryURL != null) urls.add(entryURL);
            }
            return urls.toArray(new URL[0]);
        }
    }

    protected String getExtractEntryPath(final JarEntry entry) {
        final String name = entry.getName();
        if (name.startsWith("META-INF/lib") && name.endsWith(".jar")) {
            return name.substring(name.lastIndexOf('/') + 1);
        }
        return null; // do not extract entry
    }

    protected URL extractEntry(final JarEntry entry, String path) throws Exception {
        File file = new File(extractRoot, path);
        if (entry.isDirectory()) {
            file.mkdirs();
            return null;
        }
        final String entryPath = entryPath(entry.getName());
        final InputStream entryStream;
        try {
            entryStream = new URI("jar", entryPath, null).toURL().openStream();
        } catch (IllegalArgumentException e) {
            // TODO gems '%' file name "encoding" ?!
            debug("failed to open jar:" + entryPath + " skipping entry: " + entry.getName(), e);
            return null;
        }
        final File parent = file.getParentFile();
        if (parent != null) parent.mkdirs();

        transferAndClose(() -> entryStream, () -> new FileOutputStream(file));
        file.deleteOnExit();
        // if (false) debug(entry.getName() + " extracted to " + file.getPath());
        return file.toURI().toURL();
    }

    protected String entryPath(String name) {
        if (!name.startsWith("/")) name = "/" + name;
        return path.replace(MAIN, name);
    }

    protected Object newScriptingContainer(final URL[] jars) throws Exception {
        setSystemProperty("org.jruby.embed.class.path", "");
        URLClassLoader scriptingClassLoader = new URLClassLoader(jars);
        closeables.add(scriptingClassLoader);
        Class<?> scriptingContainerClass = Class.forName("org.jruby.embed.ScriptingContainer", true, scriptingClassLoader);
        Object scriptingContainer = scriptingContainerClass.newInstance();
        debug("scripting container class loader urls: " + Arrays.toString(jars));
        invokeMethod(scriptingContainer, "setArgv", (Object) args);
        invokeMethod(scriptingContainer, "setClassLoader", new Class[]{ClassLoader.class}, scriptingClassLoader);
        return scriptingContainer;
    }

    protected int launchJRuby(final URL[] jars) throws Exception {
        final Object scriptingContainer = newScriptingContainer(jars);
        debug("invoking " + archive + " with: " + Arrays.deepToString(args));
        Object outcome = invokeMethod(scriptingContainer, "runScriptlet", launchScript());
        return (outcome instanceof Number) ? ((Number) outcome).intValue() : 0;
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
        if (isDebug()) System.out.println(msg);
        if (isDebug() && t != null) t.printStackTrace(System.out);
    }

    protected static void debug(Throwable t) {
        debug(t, System.out);
    }

    private static void debug(Throwable t, PrintStream out) {
        if (isDebug()) t.printStackTrace(out);
    }

    protected void warn(String msg) {
        System.out.println("WARNING: " + msg);
    }

    protected static void error(Throwable t) {
        error(t.toString(), t);
    }

    protected static void error(String msg, Throwable t) {
        System.err.println("ERROR: " + msg);
        debug(t, System.err);
    }

    protected void deleteAll(File f) {
        try {
            if (f.isDirectory() && !isSymlink(f)) {
                File[] children = f.listFiles();
                if (children != null) {
                    for (File child : children) {
                        deleteAll(child);
                    }
                }
            }
            f.delete();
        } catch (IOException e) {
            error(e);
        }
    }

    protected boolean isSymlink(File file) throws IOException {
        if (file == null) throw new NullPointerException("File must not be null");
        final File canonical;
        if (file.getParent() == null) canonical = file;
        else {
            File parentDir = file.getParentFile().getCanonicalFile();
            canonical = new File(parentDir, file.getName());
        }
        return !canonical.getCanonicalFile().equals(canonical.getAbsoluteFile());
    }

    @Override
    public void close() {
        closeables.reversed().forEach(closeableResource -> {
            try {
                closeableResource.close();
            } catch (Exception e) {
                error("Error during shutdown", e);
            }
        });
    }

    public static void main(String[] args) {
        doStart(new JarMain(args));
    }

    protected static void doStart(final JarMain main) {
        int exit;
        try {
            exit = main.start();
        } catch (Exception e) {
            Throwable t = e;
            while (t.getCause() != null && t.getCause() != t) {
                t = t.getCause();
            }
            error(e.toString(), t);
            exit = 1;
        }
        try {
            if (isSystemExitEnabled()) System.exit(exit);
        } catch (SecurityException e) {
            debug(e);
        }
    }

    protected static Object invokeMethod(final Object self, final String name, final Object... args)
        throws Exception {

        final Class<?>[] signature = new Class[args.length];
        for (int i = 0; i < args.length; i++) signature[i] = args[i].getClass();
        return invokeMethod(self, name, signature, args);
    }

    protected static Object invokeMethod(final Object self, final String name, final Class<?>[] signature, final Object... args)
        throws Exception {
        Method method = self.getClass().getDeclaredMethod(name, signature);
        try {
            return method.invoke(self, args);
        } catch (InvocationTargetException e) {
            Throwable target = e.getTargetException();
            if (target instanceof Exception) {
                throw (Exception) target;
            }
            throw e;
        }
    }

    private static final boolean debug;

    static {
        debug = Boolean.parseBoolean(getSystemProperty("warbler.debug", "false"));
    }

    static boolean isDebug() {
        return debug;
    }

    /**
     * if warbler.skip_system_exit system property is defined, we will not
     * call System.exit in the normal flow. System.exit can cause problems
     * for wrappers like procrun
     */
    private static boolean isSystemExitEnabled() {
        return getSystemProperty("warbler.skip_system_exit") == null; //omission enables System.exit use
    }

    static String getSystemProperty(final String name) {
        return getSystemProperty(name, null);
    }

    static String getSystemProperty(final String name, final String defaultValue) {
        try {
            return System.getProperty(name, defaultValue);
        } catch (SecurityException e) {
            return defaultValue;
        }
    }

    static boolean setSystemProperty(final String name, final String value) {
        try {
            System.setProperty(name, value);
            return true;
        } catch (SecurityException e) {
            return false;
        }
    }

    static String getENV(final String name) {
        return getENV(name, null);
    }

    static String getENV(final String name, final String defaultValue) {
        try {
            if (System.getenv().containsKey(name)) {
                return System.getenv().get(name);
            }
            return defaultValue;
        } catch (SecurityException e) {
            return defaultValue;
        }
    }

    // Can be replaced with InputStream.transferTo(OutputStream) in Java 11+
    static void transferAndClose(Callable<InputStream> is, Callable<OutputStream> os) throws Exception {
        try (InputStream input = is.call(); OutputStream output = os.call()) {
            byte[] buf = new byte[16384];
            int bytesRead;
            while ((bytesRead = input.read(buf)) != -1) {
                output.write(buf, 0, bytesRead);
            }
        }
    }
}
