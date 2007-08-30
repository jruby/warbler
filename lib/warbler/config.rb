#--
# (c) Copyright 2007 Nick Sieger <nicksieger@gmail.com>
# See the file LICENSES.txt included with the distribution for
# software license details.
#++

require 'ostruct'

module Warbler
  # Warbler assembly configuration.
  class Config
    TOP_DIRS = %w(app config lib log vendor tmp)
    FILE = "config/warble.rb"

    # Directory where files will be staged, defaults to tmp/war
    attr_accessor :staging_dir

    # Top-level directories to be copied into WEB-INF.  Defaults to 
    # names in TOP_DIRS
    attr_accessor :dirs

    # Additional files beyond the top-level directories to include in the
    # WEB-INF directory
    attr_accessor :includes

    # Files to exclude from the WEB-INF directory
    attr_accessor :excludes

    # Java libraries to copy to WEB-INF/lib
    attr_accessor :java_libs

    # Rubygems to install into the webapp at WEB-INF/gems
    attr_accessor :gems

    # Whether to include dependent gems (default true)
    attr_accessor :gem_dependencies

    # Public HTML directory file list, to be copied into the root of the war
    attr_accessor :public_html

    # Name of war file (without the .war), defaults to the directory name containing
    # the Rails application
    attr_accessor :war_name

    # Extra configuration for web.xml/goldspike. These options are particular
    # to Goldspike's Rails servlet and web.xml file.
    #  
    # * <tt>webxml.standalone</tt> -- whether the .war file is "standalone",
    #   meaning JRuby, all java and gem dependencies are completely embedded
    #   in file.  One of +true+ (default) or +false+.
    # * <tt>webxml.jruby_home</tt> -- required if standalone is false.  The
    #   directory containing the JRuby installation to use when the app is
    #   running.
    # * <tt>webxml.rails_env</tt> -- the Rails environment to use for the
    #   running application, usually either development or production (the
    #   default).
    # * <tt>webxml.pool.maxActive</tt> -- maximum number of pooled Rails
    #   application runtimes (default 4)
    # * <tt>webxml.pool.minIdle</tt> -- minimum number of pooled runtimes to
    #   keep around during idle time (default 2)
    # * <tt>webxml.pool.checkInterval</tt> -- how often to check whether the
    #   pool size is within minimum and maximum limits, in milliseconds
    #   (default 0)
    # * <tt>webxml.pool.maxWait</tt> -- how long a waiting thread should wait
    #   for a runtime before giving up, in milliseconds (default 30000)
    # * <tt>webxml.jndi</tt> -- the name of a JNDI data source name to be
    #   available to the application
    # * <tt>webxml.servlet_name</tt> -- the name of the servlet to receive all
    #   requests.  One of +files+ or +rails+.  Goldspike's default behavior is
    #   to route first through the FileServlet, and if the file isn't found,
    #   it is forwarded to the RailsServlet.  Use +rails+ if your application
    #   server is fronted by Apache or something else that will handle static
    #   files.
    attr_accessor :webxml

    def initialize
      @staging_dir = "tmp/war"
      @dirs        = TOP_DIRS
      @includes    = FileList[]
      @excludes    = FileList["#{WARBLER_HOME}/**/*"]
      @java_libs   = FileList["#{WARBLER_HOME}/lib/*.jar"]
      @gems        = default_gems
      @gem_dependencies = true
      @public_html = FileList["public/**/*"]
      @webxml      = default_webxml_config
      @war_name    = if defined?(RAILS_ROOT)
        File.basename(File.expand_path(RAILS_ROOT))
      else
        File.basename(File.expand_path(Dir.getwd))  
      end
      yield self if block_given?
      @excludes << @staging_dir
    end

    def gem_target_path
      "#{@staging_dir}/WEB-INF/gems"
    end

    private
    def default_webxml_config
      c = OpenStruct.new
      c.standalone = true
      c.rails_env  = "production"
      c.pool       = OpenStruct.new
      c
    end

    def default_gems
      File.directory?("vendor/rails") ? [] : ["rails"]
    end
  end
end