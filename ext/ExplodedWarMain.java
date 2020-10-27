/**
 * Copyright (c) 2010-2012 Engine Yard, Inc.
 * Copyright (c) 2007-2009 Sun Microsystems, Inc.
 * This source code is available under the MIT license.
 * See the file LICENSE.txt for details.
 */

import java.io.InputStream;
import java.io.FileInputStream;
import java.io.ByteArrayInputStream;
import java.io.SequenceInputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;

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


public class ExplodedWarMain {
    // Shell arguments
    private final String[] arguments;

    // The root of the exploded war archive
    private File warRoot;

    // The root of the project within the war
    private File webRoot;

    // An instance of Jruby scripting container used to run the application
    private Object jruby;
    private Object rubyInstanceConfig;

    //----------------------------------------------------------------------------------------------
    // Constructor getting args from the system
    ExplodedWarMain(String[] arguments) throws IOException {
        this.arguments = arguments;
        this.warRoot = new File(new File("./lib/war").getCanonicalPath());
        this.webRoot = new File(warRoot, "/WEB-INF/");
    }

    //----------------------------------------------------------------------------------------------
    // FIXME: Catch and log any exceptions to console
    public static void main(String[] args) throws Exception {
        ExplodedWarMain main = new ExplodedWarMain(args);
        System.exit(main.start());
    }

    protected int start() throws Exception {
        final List<String> argsList = Arrays.asList(arguments);
        final int sIndex = argsList.indexOf("-S");

        // No command specified, so starting the web server by default
        if (sIndex == -1) {
            launchWebServer();
            return 0;
        }

        // Extract the command from the args list and launch it in jruby
        String execArg = argsList.get(sIndex + 1);
        String[] executableArgv = argsList.subList(sIndex + 2, argsList.size()).toArray(new String[0]);
        return launchCommand(execArg, executableArgv);
    }

    //----------------------------------------------------------------------------------------------
    private int launchCommand(String command, String[] commandArgs) throws Exception {
        if (command.equals("rails")) {
            command = "bin/rails";
        } else {
            System.out.println("Only -S rails is supported for now");
            return 1;
        }

        // Setup jruby environment in preparation for running the script
        initJRubyContainer(commandArgs);

        // Execute the ruby script
        return launchJRubyCommand(command, commandArgs);
    }

    //----------------------------------------------------------------------------------------------
    protected int launchJRubyCommand(String command, String args[]) throws Exception {
        // Find the path for the file to execute for the given command
        final String executablePath = findExecutableFile(command);

        // Set the executable file and process arguments on jruby
        invokeMethod(jruby, "setScriptFilename", executablePath);
        invokeMethod(rubyInstanceConfig, "processArguments", (Object) args);

        // Generate a ruby script that prepares the environment for executing ruby scripts
        final CharSequence execScriptEnvPre = executableScriptEnvPrefix();

        // Load the command script and prepend it with the initialization code
        Object executableInput = new SequenceInputStream(
            new ByteArrayInputStream(execScriptEnvPre.toString().getBytes()),
            (InputStream) invokeMethod(rubyInstanceConfig, "getScriptSource")
        );

        // Finally, ask jruby to execute the script
        Object runtime = invokeMethod(jruby, "getRuntime");
        Object outcome = invokeMethod(runtime, "runFromMain",
            new Class[] { InputStream.class, String.class },
            executableInput,
            executablePath
        );

        /// Cast the result of the script into an exit code
        return (outcome instanceof Number) ? ((Number) outcome).intValue() : 0;
    }

    //----------------------------------------------------------------------------------------------
    private String findExecutableFile(String command) {
        final File commandFile = new File(webRoot, command);
        if (commandFile.exists()) return commandFile.getAbsolutePath();
        throw new IllegalStateException("Failed to locate the command file: '" + commandFile + "'");
    }

    //----------------------------------------------------------------------------------------------
    static void debug(String message) {
        System.out.println(message);
    }

    //----------------------------------------------------------------------------------------------
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
            if (System.getenv().containsKey(name)) {
                return System.getenv().get(name);
            }
            return defaultValue;
        }
        catch (SecurityException e) {
            return defaultValue;
        }
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
    protected CharSequence executableScriptEnvPrefix() {
        final String gemsDir = new File(webRoot, "gems").getAbsolutePath();
        final String gemfile = new File(webRoot, "Gemfile").getAbsolutePath();

        return (
            "ENV['GEM_HOME'] = ENV['GEM_PATH'] = '"+ gemsDir +"' \n" +
            "ENV['BUNDLE_GEMFILE'] ||= '"+ gemfile +"' \n" +
            "require '" + webRoot + "/../META-INF/init.rb'"
        );
    }

    //----------------------------------------------------------------------------------------------
    protected void initJRubyContainer(String[] commandArgs) throws Exception {
        this.jruby = newScriptingContainer(loadJarUrls(webRoot));

        invokeMethod(jruby, "setArgv", (Object) commandArgs);
        invokeMethod(jruby, "setCurrentDirectory", webRoot.getAbsolutePath());
        invokeMethod(jruby, "setHomeDirectory", "uri:classloader:/META-INF/jruby.home");

        // for some reason, the container needs to run a scriptlet in order for it
        // to be able to find the gem executables later
        invokeMethod(jruby, "runScriptlet", "SCRIPTING_CONTAINER_INITIALIZED=true");

        // Allow ruby to modify the environment
        final Object provider = invokeMethod(jruby, "getProvider");
        this.rubyInstanceConfig = invokeMethod(provider, "getRubyInstanceConfig");
        invokeMethod(rubyInstanceConfig, "setUpdateNativeENVEnabled", new Class[] { Boolean.TYPE }, false);
    }

    //----------------------------------------------------------------------------------------------
    private Properties getWebserverProperties() throws Exception {
        File propsFilePath = new File(webRoot, "/webserver.properties");

        Properties props = new Properties();
        try(InputStream propsStream = new FileInputStream(propsFilePath)) {
            props.load(propsStream);
        } catch (Exception e) {
            debug("Error while loading webserver properties file: " + e);
        }

        String port = getSystemProperty("warbler.port", getENV("PORT", "8080"));
        String host = getSystemProperty("warbler.host", "0.0.0.0");

        String webserverConfig = getSystemProperty("warbler.webserver_config", getENV("WARBLER_WEBSERVER_CONFIG"));
        if (webserverConfig == null) {
            String defaultWebserverConfigPath = new File(webRoot, "/webserver.xml").getCanonicalPath();
            URI defaultWebserverConfigURI = new URI("jar", defaultWebserverConfigPath, null);
            webserverConfig = defaultWebserverConfigURI.toURL().toString();
        }
        debug("Jetty config to be used: " + webserverConfig);

        // Substitute template values in webserver props
        for (Map.Entry entry : props.entrySet()) {
            String val = (String) entry.getValue();
            val = val.replace("{{warfile}}", warRoot.getAbsolutePath()).
                      replace("{{port}}", port).
                      replace("{{host}}", host).
                      replace("{{config}}", webserverConfig).
                      replace("{{webroot}}", webRoot.getAbsolutePath());
            entry.setValue(val);
        }

        // Push all properties from the file into the global system context
        if (props.getProperty("props") != null) {
            String[] propsToSet = props.getProperty("props").split(",");
            for ( String key : propsToSet ) {
                setSystemProperty(key, props.getProperty(key));
            }
        }

        return props;
    }

    //----------------------------------------------------------------------------------------------
    public void launchWebServer() throws Exception {
        // Load web server properties file
        Properties props = getWebserverProperties();

        // Get the name of the main jetty class
        String mainClass = props.getProperty("mainclass");
        if (mainClass == null) {
            throw new IllegalArgumentException("Unknown webserver main class (webserver.properties file is missing 'mainclass' property)");
        }

        // Load Jetty jar file
        File jarFile = new File(webRoot, "webserver.jar");
        URLClassLoader loader = new URLClassLoader(new URL[] {jarFile.toURI().toURL()});
        Thread.currentThread().setContextClassLoader(loader);

        // Get the jetty class object based on its name
        Class<?> klass = Class.forName(mainClass, true, loader);
        Method main = klass.getDeclaredMethod("main", new Class[] { String[].class });

        // Start jetty
        main.invoke(null, new Object[] { launchWebServerArguments(props) });
    }

    //----------------------------------------------------------------------------------------------
    private String[] launchWebServerArguments(Properties props) {
        String[] newArgs = arguments;

        if (props.getProperty("args") != null) {
            String[] insertArgs = props.getProperty("args").split(",");
            newArgs = new String[arguments.length + insertArgs.length];
            for (int i = 0; i < insertArgs.length; i++) {
                newArgs[i] = props.getProperty(insertArgs[i], "");
            }
            System.arraycopy(arguments, 0, newArgs, insertArgs.length, arguments.length);
        }

        return newArgs;
    }

    //----------------------------------------------------------------------------------------------
    // Finds all jar files in the lib directory of the project and returns them as an array
    public static URL[] loadJarUrls(File root) throws Exception {
        List<URL> jars = new ArrayList<URL>();
        File libDir = new File(root, "lib");
        File[] libFiles = libDir.listFiles();

        if (libFiles != null) {
            for (File f : libFiles) {
                if (f.isFile() && f.getName().endsWith(".jar")) {
                    jars.add(f.toURI().toURL());
                }
            }
        }

        return jars.toArray(new URL[jars.size()]);
    }

    //----------------------------------------------------------------------------------------------
    protected static Object newScriptingContainer(final URL[] jars) throws Exception {
        setSystemProperty("org.jruby.embed.class.path", "");

        URLClassLoader classLoader = new URLClassLoader(jars);
        Class scriptingContainerClass = Class.forName("org.jruby.embed.ScriptingContainer", true, classLoader);
        Object jruby = scriptingContainerClass.newInstance();
        invokeMethod(jruby, "setClassLoader", new Class[] { ClassLoader.class }, classLoader);

        return jruby;
    }
}
