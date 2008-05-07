#--
# (c) Copyright 2007-2008 Sun Microsystems, Inc.
# See the file LICENSES.txt included with the distribution for
# software license details.
#++

require 'ostruct'

module Warbler
  # Warbler assembly configuration.
  class Config
    TOP_DIRS = %w(app config lib log vendor tmp)
    FILE = "config/warble.rb"
    BUILD_GEMS = %w(warbler rake rcov)

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

    # Java classes and other files to copy to WEB-INF/classes
    attr_accessor :java_classes

    # Java libraries to copy to WEB-INF/lib
    attr_accessor :java_libs

    # Rubygems to install into the webapp at WEB-INF/gems
    attr_accessor :gems

    # Whether to include dependent gems (default true)
    attr_accessor :gem_dependencies

    # Public HTML directory file list, to be copied into the root of the war
    attr_accessor :public_html

    # Container of pathmaps used for specifying source-to-destination transformations
    # under various situations (<tt>public_html</tt> and <tt>java_classes</tt> are two
    # entries in this structure).
    attr_accessor :pathmaps

    # Name of war file (without the .war), defaults to the directory name containing
    # the Rails application
    attr_accessor :war_name

    # Extra configuration for web.xml. Controls how the dynamically-generated web.xml
    # file is generated.
    #
    # * <tt>webxml.jndi</tt> -- the name of one or more JNDI data sources name to be
    #   available to the application. Places appropriate &lt;resource-ref&gt; entries
    #   in the file.
    # * <tt>webxml.ignored</tt> -- array of key names that will be not used to
    #   generate a context param. Defaults to ['jndi', 'booter']
    #
    # Any other key/value pair placed in the open structure will be dumped as a
    # context parameter in the web.xml file. Some of the recognized values are:
    #
    # * <tt>webxml.rails.env</tt> -- the Rails environment to use for the
    #   running application, usually either development or production (the
    #   default).
    # * <tt>webxml.jruby.min.runtimes</tt> -- minimum number of pooled runtimes to
    #   keep around during idle time
    # * <tt>webxml.jruby.max.runtimes</tt> -- maximum number of pooled Rails
    #   application runtimes
    attr_accessor :webxml

    def initialize(warbler_home = WARBLER_HOME)
      @staging_dir = File.join("tmp", "war")
      @dirs        = TOP_DIRS
      @includes    = FileList[]
      @excludes    = FileList[]
      @java_libs   = FileList["#{warbler_home}/lib/*.jar"]
      @java_classes = FileList[]
      @gems        = default_gems
      @gem_dependencies = true
      @public_html = FileList["public/**/*"]
      @pathmaps    = default_pathmaps
      @webxml      = default_webxml_config
      @rails_root  = File.expand_path(defined?(RAILS_ROOT) ? RAILS_ROOT : Dir.getwd)
      @war_name    = File.basename(@rails_root)
      yield self if block_given?
      @excludes += warbler_vendor_excludes(warbler_home)
      @excludes << @staging_dir
    end

    def gems=(value)
      @gems = Warbler::Gems.new(value)
    end

    private
    def warbler_vendor_excludes(warbler_home)
      warbler = File.expand_path(warbler_home)
      if warbler =~ %r{^#{@rails_root}/(.*)}
        FileList["#{$1}"]
      else
        []
      end
    end

    def default_pathmaps
      p = OpenStruct.new
      p.public_html  = ["%{public/,}p"]
      p.java_libs    = ["WEB-INF/lib/%f"]
      p.java_classes = ["WEB-INF/classes/%p"]
      p.application  = ["WEB-INF/%p"]
      p.gemspecs     = ["WEB-INF/gems/specifications/%f"]
      p.gems         = ["WEB-INF/gems/gems/%n"]
      p
    end

    def default_webxml_config
      c = WebxmlOpenStruct.new
      c.rails.env  = "production"
      c.public.root = '/'
      c.jndi = nil
      c.ignored = %w(jndi booter)
      c
    end

    def default_gems
      gems = Warbler::Gems.new
      # Include all gems which are used by the web application, this only works when run as a plugin
      #for gem in Gem.loaded_specs.values
      #  next if BUILD_GEMS.include?(gem.name)
      #  gems[gem.name] = gem.version.version
      #end
      gems << "rails" unless File.directory?("vendor/rails")
      gems
    end
  end

  class WebxmlOpenStruct < OpenStruct
    def initialize
      @table = Hash.new {|h,k| h[k] = WebxmlOpenStruct.new }
    end

    def servlet_context_listener
      case self.booter
      when :rack
        "org.jruby.rack.RackServletContextListener"
      when :merb
        "org.jruby.rack.merb.MerbServletContextListener"
      else # :rails, default
        "org.jruby.rack.rails.RailsServletContextListener"
      end
    end

    def context_params
      params = {}
      @table.each do |k,v|
        case v
        when WebxmlOpenStruct
          nested_params = v.context_params
          nested_params.each do |nk,nv|
            params["#{k}.#{nk}"] = nv
          end
        else
          params[k] = v.to_s
        end
      end
      params.delete_if {|k,v| ['ignored', *ignored].include?(k.to_s) }
      params
    end
  end
end