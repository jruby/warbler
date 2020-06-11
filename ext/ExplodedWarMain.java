/**
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

import java.lang.reflect.Method;
import java.io.InputStream;
import java.io.ByteArrayInputStream;
import java.io.SequenceInputStream;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.net.URI;
import java.net.URLClassLoader;
import java.net.URL;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Properties;
import java.util.Map;
import java.util.jar.JarEntry;

public class ExplodedWarMain {
    static void debug(String message) {
        System.out.println(message);
    }

    //----------------------------------------------------------------------------------------------
    static boolean setSystemProperty(final String name, final String value) {
        try {
            System.setProperty(name, value);
            return true;
        }
        catch (SecurityException e) {
            return false;
        }
    }

    //----------------------------------------------------------------------------------------------
    static protected void initJRubyScriptingEnv(Object scriptingContainer) throws Exception {
        // for some reason, the container needs to run a scriptlet in order for it
        // to be able to find the gem executables later
        invokeMethod(scriptingContainer, "runScriptlet", "SCRIPTING_CONTAINER_INITIALIZED=true");

        invokeMethod(scriptingContainer, "setHomeDirectory", "uri:classloader:/META-INF/jruby.home");
    }

    //----------------------------------------------------------------------------------------------
    protected static Object invokeMethod(final Object self, final String name, final Object... args) throws NoSuchMethodException, IllegalAccessException, Exception {
        final Class[] signature = new Class[args.length];
        for ( int i = 0; i < args.length; i++ ) {
            signature[i] = args[i].getClass();
        }
        return invokeMethod(self, name, signature, args);
    }

    //----------------------------------------------------------------------------------------------
    protected static Object invokeMethod(final Object self, final String name, final Class[] signature, final Object... args) throws NoSuchMethodException, IllegalAccessException, Exception {
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

    //----------------------------------------------------------------------------------------------
    protected static CharSequence executableScriptEnvPrefix(String extractRoot) {
          final String gemsDir = new File(extractRoot, "gems").getAbsolutePath();
          final String gemfile = new File(extractRoot, "Gemfile").getAbsolutePath();
          System.out.println("setting GEM_HOME to " + gemsDir);
          System.out.println("... and BUNDLE_GEMFILE to " + gemfile);

          // ideally this would look up the config.override_gem_home setting
          return "ENV['GEM_HOME'] = ENV['GEM_PATH'] = '"+ gemsDir +"' \n" +
          "ENV['BUNDLE_GEMFILE'] ||= '"+ gemfile +"' \n" +
          "require '" + extractRoot + "/../META-INF/init.rb'";
    }

    //----------------------------------------------------------------------------------------------
    protected static String locateExecutable(Object scriptingContainer, String root, final CharSequence envPreScript, String executable) throws Exception {
          final File exec = new File(root, executable);
          debug("locating script " + root + " " + executable);
          return exec.exists() ? exec.getAbsolutePath() : null;
    }

    //----------------------------------------------------------------------------------------------
    protected static Object newScriptingContainer(final URL[] jars, String[] args) throws Exception {
        setSystemProperty("org.jruby.embed.class.path", "");

        URLClassLoader classLoader = new URLClassLoader(jars);

        Class scriptingContainerClass = Class.forName("org.jruby.embed.ScriptingContainer", true, classLoader);
        Object scriptingContainer = scriptingContainerClass.newInstance();

        System.out.println("scripting container class loader urls: " + Arrays.toString(jars));
        invokeMethod(scriptingContainer, "setArgv", (Object) args);
        invokeMethod(scriptingContainer, "setClassLoader", new Class[] { ClassLoader.class }, classLoader);

        return scriptingContainer;
    }

    //----------------------------------------------------------------------------------------------
    protected static int launchJRuby(final URL[] jars, File root, String executable, String args[]) throws Exception {
        final Object scriptingContainer = newScriptingContainer(jars, args);

        invokeMethod(scriptingContainer, "setArgv", (Object) args);
        debug("setArgv: " + args);

        invokeMethod(scriptingContainer, "setCurrentDirectory", root.getAbsolutePath());
        debug("setCurrentDirectory: " + root.getAbsolutePath());

        initJRubyScriptingEnv(scriptingContainer);

        final Object provider = invokeMethod(scriptingContainer, "getProvider");
        final Object rubyInstanceConfig = invokeMethod(provider, "getRubyInstanceConfig");

        invokeMethod(rubyInstanceConfig, "setUpdateNativeENVEnabled", new Class[] { Boolean.TYPE }, false);

        final CharSequence execScriptEnvPre = executableScriptEnvPrefix(root.getAbsolutePath());

        final String executablePath = locateExecutable(scriptingContainer, root.getCanonicalPath(), execScriptEnvPre, executable);
        if ( executablePath == null ) {
            throw new IllegalStateException("failed to locate gem executable: '" + executable + "'");
        }

        invokeMethod(scriptingContainer, "setScriptFilename", executablePath);
        debug("setScriptFilename: " + executablePath);

        invokeMethod(rubyInstanceConfig, "processArguments", (Object) args);

        Object runtime = invokeMethod(scriptingContainer, "getRuntime");

        debug("loading resource: " + executablePath);
        Object executableInput = new SequenceInputStream(
            new ByteArrayInputStream(execScriptEnvPre.toString().getBytes()),
            (InputStream) invokeMethod(rubyInstanceConfig, "getScriptSource")
        );

        debug("invoking " + executablePath + " with: " + Arrays.toString(args));

        Object outcome = invokeMethod(
            runtime,
            "runFromMain",
            new Class[] { InputStream.class, String.class },
            executableInput,
            executablePath
        );
        return ( outcome instanceof Number ) ? ( (Number) outcome ).intValue() : 0;
    }

    //----------------------------------------------------------------------------------------------
    public static URL[] loadJarUrls(File root) throws Exception {
        List<URL> jars = new ArrayList<URL>();

        File[] files = new File(root, "lib").listFiles();

        for (File f : files) {
          if (f.isFile() && f.getName().endsWith(".jar"))
            jars.add(f.toURI().toURL());
        }
        return jars.toArray(new URL[jars.size()]);
    }

    //----------------------------------------------------------------------------------------------
    public static void launchWebServer() {
        debug("Jetty will start here");
    }

    //----------------------------------------------------------------------------------------------
    public static void main(String args[]) throws Exception {
        String warRoot = "./lib/war";
        File root = new File(new File(warRoot + "/WEB-INF/").getCanonicalPath());

        debug("Root: " + root.toString());

        final List<String> argsList = Arrays.asList(args);
        final int sIndex = argsList.indexOf("-S");

        if (sIndex == -1) {
            debug("No command specified, starting a web server");
            launchWebServer();
            return;
        }

        String[] arguments = argsList.subList(0, sIndex).toArray(new String[0]);
        String execArg = argsList.get(sIndex + 1);
        String[] executableArgv = argsList.subList(sIndex + 2, argsList.size()).toArray(new String[0]);

        if (execArg.equals("rails")) {
            // The rails executable doesn't play well with ScriptingContainer, so we've packaged the
            // same script that would have been generated by `rake rails:update:bin`
            execArg = "/../META-INF/rails.rb";
        } else {
            System.out.println("Only -S rails is supported for now");
            System.exit(1);
        }

        URL[] jars = loadJarUrls(root);
        debug("Launching jruby with script '" + execArg + "' and arguments: " + executableArgv);
        launchJRuby(jars, root, execArg, executableArgv);
    }
}
