# Warbler web application assembly configuration file
Warbler::Config.new do |config|
  # Temporary directory where the application is staged
  # config.staging_dir = "tmp/war"

  # Application directories to be included in the webapp.
  config.dirs = %w(app config lib log vendor tmp)

  # Additional files/directories to include, above those in config.dirs
  # config.includes = FileList["db"]

  # Additional files/directories to exclude
  # config.excludes = FileList["lib/tasks/*"]

  # Additional Java .jar files to include.  Note that if .jar files are placed
  # in lib (and not otherwise excluded) then they need not be mentioned here
  # config.java_libs = FileList["lib/java/*.jar"]
  # config.java_libs << "lib/java/*.jar"

  # External gems to be packaged in the webapp.
  # config.gems = ["ActiveRecord-JDBC", "jruby-openssl"]
  # config.gems << "tzinfo"

  # Files to be included in the root of the webapp
  # config.public_html = FileList["public/**/*", "doc/**/*"]

  # Name of the war file (without the .war) -- defaults to the basename
  # of RAILS_ROOT
  # config.war_name = "mywar"

  # True if the webapp has no external dependencies
  config.webxml.standalone = true

  # Location of JRuby, required for non-standalone apps
  # config.webxml.jruby_home = <jruby/home>

  # Value of RAILS_ENV for the webapp
  config.webxml.rails_env = 'production'

  # Control the pool of Rails runtimes
  # (Goldspike-specific; see README for details)
  # config.webxml.pool.maxActive = 4
  # config.webxml.pool.minIdle = 2
  # config.webxml.pool.checkInterval = 0
  # config.webxml.pool.maxWait = 30000

  # JNDI data source name
  # config.webxml.jndi = 'jdbc/rails'
end