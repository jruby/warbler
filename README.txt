= Warbler

Warbler is a gem to make a .war file out of a Rails, Merb, or Rack-based
application. The intent is to provide a minimal, flexible, ruby-like way to
bundle up all of your application files for deployment to a Java application
server.

Warbler provides a sane set of out-of-the box defaults that should allow most
Rails applications without external gem dependencies (aside from Rails itself)
to assemble and Just Work.

Warbler bundles JRuby and the JRuby-Rack servlet adapter for dispatching
requests to your application inside the java application server, and assembles
all jar files in WARBLER_HOME/lib/*.jar into your application. No external
dependencies are downloaded.

== Getting Started

1. Install the gem: <tt>gem install warbler</tt>.
2. Run warbler in the top directory of your Rails application: <tt>warble</tt>.
3. Deploy your railsapp.war file to your favorite Java application server.

== Usage

Warbler's +warble+ command is just a small wrapper around Rake with internally
defined tasks. (Notice "rake" still prints out in the message, but you should
substitute "warble" for "rake" on the command line when running this way.)

   $ warble -T
   rake config         # Generate a configuration file to customize your war assembly
   rake pluginize      # Unpack warbler as a plugin in your Rails application
   rake war            # Create trunk.war
   rake war:app        # Copy all application files into the .war
   rake war:clean      # Clean up the .war file and the staging area
   rake war:gems       # Unpack all gems into WEB-INF/gems
   rake war:jar        # Run the jar command to create the .war
   rake war:java_libs  # Copy all java libraries into the .war
   rake war:public     # Copy all public HTML files to the root of the .war
   rake war:webxml     # Generate a web.xml file for the webapp

Warbler makes heavy use of Rake's file and directory tasks, so only recently
updated files will be copied, making repeated assemblies much faster.

== Configuration

=== Rails applications

Rails applications are detected automatically and configured appropriately.
The following items are set up for you:

* The Rails gem is packaged if you haven't vendored Rails.
* Other gems configured in Rails.configuration.gems are packaged
  (Rails 2.1 or later)
* Multi-thread-safe execution (as introduced in Rails 2.2) is detected
  and runtime pooling is disabled.

=== Merb applications

Merb applications are detected automatically, and the merb-core gem and its
dependencies are packaged.

=== Other Rack-based applications

If you have a 'config.ru' file in the top directory of your application, its
contents will be used as the rackup script for your Rack-based application.
You will probably need to specify framework and application gems in
config/warble.rb.

See <a href="http://jruby-rack.kenai.com/sources/main/show/examples">the examples in the jruby-rack project</a>
of how to configure Warbler to package Camping and Sinatra apps.

=== Configuration auto-detect notes

* If you don't have database access in the environment where you
  package your application, you may wish to set
  `Warbler.framework_detection` to false at the top of config.rb. In
  this case you may need to specify additional details such as booter,
  gems and other settings.
* A more accurate way of detecting a Merb application's gems is
  needed. Until then, you will have to specify them in
  config/warble.rb. See below.
* Is it possible to more generally detect what gems an application
  uses? Gem.loaded_specs is available, but the application needs to be
  loaded first before its contents are reliable.

=== Custom configuration

The default configuration puts application files (+app+, +config+, +lib+,
+log+, +vendor+, +tmp+) under the .war file's WEB-INF directory, and files in
+public+ in the root of the .war file. Any Java .jar files stored in lib will
automatically be placed in WEB-INF/lib for placement on the web app's
classpath.

If the default settings are not appropriate for your application, you can
customize Warbler's behavior. To customize files, libraries, and gems included
in the .war file, you'll need a config/warble.rb file. There a two ways of
doing this. With the gem, simply run

    warble config

If you have Warbler installed as a plugin, use the generator:

 script/generate warble

Finally, edit the config/warble.rb to your taste. If you install the gem but
later decide you'd like to have it as a plugin, use the +pluginize+ command:

    warble pluginize

If you wish to upgrade or switch one or more java libraries from what's
bundled in the Warbler gem, simply change the jars in WARBLER_HOME/lib, or
modify the +java_libs+ attribute of Warbler::Config to include the files you
need.

Once Warbler is installed as a plugin, you can use +rake+ to build the war
(with the same set of tasks as above).

The generated config/warble.rb file is fully-documented with the available
options and default values.

=== Web.xml

Java web applications are configured mainly through this file, and Warbler
creates a suitable default file for you for use. However, if you need to
customize it in any way, you have two options.

1. If you just want a static web.xml file whose contents you manually
   control, you may copy the one generated for you in
   <tt>tmp/war/WEB-INF/web.xml</tt> to <tt>config/web.xml</tt> and
   modify as needed. It will be copied into the webapp for you.
2. If you want to inject some dynamic information into the file, copy
   the <tt>WARBLER_HOME/web.xml.erb</tt> to
   <tt>config/web.xml.erb</tt>. Its contents will be evaluated for you
   and put in the webapp. Note that you can also pass arbitrary
   properties to the ERb template by setting
   <tt>config.webxml.customkey</tt> values in your
   <tt>config/warble.rb</tt> file.

For more information on configuration, see Warbler::Config.

=== Troubleshooting

If Warbler isn't packaging the files you were expecting, there are several
debug tasks available to give you more insight into what's going on.

* <tt>war:debug</tt> prints a YAML dump of the current configuration
* <tt>war:debug:X</tt> prints a list of files that Warbler will
  include during that stage of assembly. Valid values of <tt>X</tt>
  are <tt>app, java_libs, gems, public, includes, excludes</tt>.

== Source

You can get the Warbler source using Git, in any of the following ways:

   git clone git://kenai.com/warbler~main
   git clone git://git.caldersphere.net/warbler.git
   git clone git://github.com/nicksieger/warbler.git

You can also download a tarball of Warbler source at
http://github.com/nicksieger/warbler/tree/master.

== License

Warbler is provided under the terms of the MIT license.

Warbler (c) 2007-2009 Sun Microsystems, Inc.

Warbler also bundles several other pieces of software for convenience.
Please read the file LICENSES.txt to ensure that you agree with the
terms of all the components.
