= Warbler

Warbler is a gem to make a .war file out of a Rails project. The intent is to provide a minimal,
flexible, ruby-like, way to bundle up all of your application files for deployment to a Java
application server.

Warbler provides an out-of-the box set of defaults that 

== Getting Started

1. Install the gem: <tt>gem install warbler</tt>.
2. Run warbler in the top directory of your Rails application: <tt>warble</tt>.
3. Deploy your railsapp.war file to your favorite Java application server.

== Configuration

The default configuration puts application files (+app+, +config+, +lib+, +log+, +vendor+, +tmp+) under the .war file's WEB-INF directory, and files in +public+ in the root of the .war file.  Any Java .jar files stored in lib will automatically be placed in WEB-INF/lib for placement on the web app's classpath.

To customize files, libraries, and gems included in the .war file, run the +warbler+ generator, which will create a config/warbler.rb file.

=== Web.xml configuration

These options are particular to Goldspike's Rails servlet and web.xml file.

* <tt>config.webxml.standalone</tt> -- whether the .war file is "standalone", meaning JRuby, all java and gem dependencies are completely embedded in file.  One of +true+ (default) or +false+.
* <tt>config.webxml.jruby_home</tt> -- required if standalone is false.  The directory containing the JRuby installation to use when the app is running.
* <tt>config.webxml.rails_env</tt> -- the Rails environment to use for the running application, usually either development or production (the default).
* <tt>config.webxml.pool.maxActive</tt> -- maximum number of pooled Rails application runtimes (default 4)
* <tt>config.webxml.pool.minIdle</tt> -- minimum number of pooled runtimes to keep around during idle time (default 2)
* <tt>config.webxml.pool.checkInterval</tt> -- how often to check whether the pool size is within minimum and maximum limits, in milliseconds (default 0)
* <tt>config.webxml.pool.maxWait</tt> -- how long a waiting thread should wait for a runtime before giving up, in milliseconds (default 30000)
* <tt>config.webxml.jndi</tt> -- the name of a JNDI data source name to be available to the application
* <tt>config.webxml.servlet_name</tt> -- the name of the servlet to receive all requests.  One of +files+ or +rails+.  Goldspike's default behavior is to route first through the FileServlet, and if the file isn't found, it is forwarded to the RailsServlet.  Use +rails+ if your application server is fronted by Apache or something else that will handle static files.

=== Caveats

Warbler requires that RAILS_ROOT will effectively be set to war/WEB-INF when running inside the war, while the application public files will be in the war root.  The purpose is to make the application structure match the Java webapp archive structure, where WEB-INF is a protected directory not visible to the webserver.  Because of this change, features of Rails that expect the public assets directory to live in RAILS_ROOT/public may not function properly.  However, we feel that the added security of conforming to the webapp structure is worth these minor inconveniences.

For Rails 1.2.3, the items that may need your attention are:

* Page caching will not work unless you set <tt>ActionController::Base.page_cache_directory = "#{RAILS_ROOT}/.."</tt>
* Asset tag timestamp calculation (e.g., <tt>javascripts/prototype.js?1188482864</tt>) will not happen.  The workaround is to control this manually by setting the RAILS_ASSET_ID environment variable.
* Automatic inclusion of <tt>application.js</tt> through <tt>javascript_include_tag :defaults</tt> will not work.  The workaround is to include it yourself with <tt>javascript_include_tag "application"</tt>.

== License

Warbler is provided under the terms of the MIT license.  Warbler (c) 2007 Nick Sieger <nicksieger@gmail.com>.

Warbler also bundles several other pieces of software.  Please read the file LICENSES.txt to ensure that you agree with the terms of all the components.
