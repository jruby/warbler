= Warbler

Warbler is a gem to make a .war file out of a Rails, Merb, or Rack-based
application. The intent is to provide a minimal, flexible, ruby-like way to
bundle up all of your application files for deployment to a Java application
server.

Warbler provides a sane set of out-of-the box defaults that should allow most
Rails applications without external gem dependencies (aside from Rails itself)
to assemble and Just Work.

== Getting Started

1. Install the gem: <tt>gem install warbler</tt>.
2. Run warbler in the top directory of your Rails application: <tt>warble</tt>.
3. Deploy your myapp.war file to your favorite Java application server.

== Usage

Warbler's +warble+ command is just a small wrapper around Rake with internally
defined tasks.

    $ warble -T
    warble config      # Generate a configuration file to customize your war
    warble executable  # Feature: make an executable archive
    warble gemjar      # Feature: package gem repository inside a jar
    warble pluginize   # Install Warbler tasks in your Rails application
    warble version     # Display version of Warbler
    warble war         # Create the project .war file
    warble war:clean   # Remove the .war file
    warble war:debug   # Dump diagnostic information

If you'd like to control Warbler from your own project's Rakefile,
simply add the following code somewhere in the Rakefile:

    require 'warbler'
    Warbler::Task.new

Now you should be able to invoke "rake war" to create your war file.

== Features

Warbler "features" are small Rake tasks that run before the creation
of the war file and make manipulations to the war file structure.

You can either add features to the warbler command line:

    warble FEATURE war

or configure them in config/warble.rb to always be used.

   config.features = %w(FEATURE)

Currently, two features are available.

* +gemjar+: This bundles all gems into a single gem file to reduce the
  number of files in the .war. This is mostly useful for Google
  AppEngine where the number of files per application has a limit.
* +executable+: This bundles an embedded web server into the .war so
  that it can either be deployed into a traditional java web server or
  run as a standalone application using 'java -jar myapp.war'.

Features may form the basis for a third-party plugin system in the
future if there is demand.

== Configuration

=== Bundler

Applications that use Bundler[http://gembundler.com/], detected via
presence of a +Gemfile+, will have the gems packaged up into the war
file. The .bundle/environment.rb file will be included for you, and
rewritten to use the paths to the gems inside the war.

=== Rails applications

Rails applications are detected automatically and configured appropriately.
The following items are set up for you:

* The Rails gem is packaged if you haven't vendored Rails.
* Other gems configured in Rails.configuration.gems are packaged
  (Rails 2.1 - 2.3)
* Multi-thread-safe execution (as introduced in Rails 2.2) is detected
  and runtime pooling is disabled.

=== Merb applications

Merb applications are detected automatically, and the merb-core gem and its
dependencies are packaged.

=== Other Rack-based applications

If you have a 'config.ru' file in the top directory or one of the
immediate subdirectories of your application, it will be included and
used as the rackup script for your Rack-based application. You will
probably need to specify framework and application gems in
config/warble.rb unless you're using Bundler to manage your gems.

See {the examples in the jruby-rack project}[http://github.com/nicksieger/jruby-rack/tree/master/examples/]
of how to configure Warbler to package Camping and Sinatra apps.

=== Configuration auto-detect notes

* Warbler will load the "environment" Rake task in a Rails application
  to try to detect some configuration. If you don't have database
  access in the environment where you package your application, you
  may wish to set `Warbler.framework_detection` to false at the top of
  config.rb. In this case you may need to specify additional details
  such as booter, gems and other settings that would normally be
  gleaned from the application configuration.
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

Finally, edit the config/warble.rb to your taste. The generated
config/warble.rb file is fully-documented with the available options
and default values.

=== Web.xml

Java web applications are configured mainly through this file, and Warbler
creates a suitable default file for you for use. However, if you need to
customize it in any way, you have two options.

1. If you just want a static web.xml file whose contents you manually
   control, you may unzip the one generated for you in
   <tt>yourapp.war:WEB-INF/web.xml</tt> to <tt>config/web.xml</tt> and
   modify as needed. It will be copied into subsequent copies of the
   war file for you.
2. If you want to inject some dynamic information into the file, copy
   the <tt>WARBLER_HOME/web.xml.erb</tt> to
   <tt>config/web.xml.erb</tt>. Its contents will be evaluated for you
   and put in the webapp. Note that you can also pass arbitrary
   properties to the ERb template by setting
   <tt>config.webxml.customkey</tt> values in your
   <tt>config/warble.rb</tt> file.

For more information on configuration, see Warbler::Config.

=== Troubleshooting

If Warbler isn't packaging the files you were expecting, use the
war:debug task to give you more insight into what's going on.

== Source

You can get the Warbler source using Git, in any of the following ways:

   git clone git://kenai.com/warbler~main
   git clone git://git.caldersphere.net/warbler.git
   git clone git://github.com/nicksieger/warbler.git

You can also download a tarball of Warbler source at
http://github.com/nicksieger/warbler/tree/master.

== Development

You can develop Warbler with any implementation of Ruby. To write
Warbler code and run specs, you need to have Bundler installed
and run "bundle install" once.

After that, simply run "rake".

== License

Warbler is provided under the terms of the MIT license.

Warbler (c) 2010 Engine Yard, Inc.
Warbler (c) 2007-2009 Sun Microsystems, Inc.
