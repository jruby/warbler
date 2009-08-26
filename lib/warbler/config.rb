#--
# (c) Copyright 2007-2009 Sun Microsystems, Inc.
# See the file LICENSES.txt included with the distribution for
# software license details.
#++

require 'ostruct'

module Warbler
  # Warbler assembly configuration.
  class Config
    TOP_DIRS = %w(app config lib log vendor)
    FILE = "config/warble.rb"
    BUILD_GEMS = %w(warbler rake rcov)

    # Directory where files will be staged, defaults to tmp/war
    attr_accessor :staging_dir

    # Directory where the war file will be written. Can be used to direct
    # Warbler to place your war file directly in your application server's
    # autodeploy directory. Defaults to the root of the Rails directory.
    attr_accessor :autodeploy_dir

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

    # Whether to exclude **/*.log files (default is true)
    attr_accessor :exclude_logs

    # Public HTML directory file list, to be copied into the root of the war
    attr_accessor :public_html

    # Container of pathmaps used for specifying source-to-destination transformations
    # under various situations (<tt>public_html</tt> and <tt>java_classes</tt> are two
    # entries in this structure).
    attr_accessor :pathmaps

    # Name of war file (without the .war), defaults to the directory name containing
    # the Rails application
    attr_accessor :war_name

    # Name of the MANIFEST.MF template.  Defaults to the MANIFEST.MF normally generated
    # by jar -cf....
    attr_accessor :manifest_file

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
    #
    # Note that if you attempt to access webxml configuration keys in a conditional,
    # you might not obtain the result you want. For example:
    #     <%= webxml.maybe.present.key || 'default' %>
    # doesn't yield the right result. Instead, you need to generate the context parameters:
    #     <%= webxml.context_params['maybe.present.key'] || 'default' %>
    attr_accessor :webxml

    def initialize(warbler_home = WARBLER_HOME)
      @warbler_home = warbler_home
      @staging_dir = File.join("tmp", "war")
      @dirs        = TOP_DIRS.select {|d| File.directory?(d)}
      @includes    = FileList[]
      @excludes    = FileList[]
      @java_libs   = default_jar_files
      @java_classes = FileList[]
      @gems        = Warbler::Gems.new
      @gem_dependencies = true
      @exclude_logs = true
      @public_html = FileList["public/**/*"]
      @pathmaps    = default_pathmaps
      @webxml      = default_webxml_config
      @rails_root  = File.expand_path(defined?(RAILS_ROOT) ? RAILS_ROOT : Dir.getwd)
      @war_name    = File.basename(@rails_root)
      auto_detect_frameworks
      yield self if block_given?
      @excludes += warbler_vendor_excludes(warbler_home)
      @excludes += FileList["**/*.log"] if @exclude_logs
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
      c.rails.env  = ENV['RAILS_ENV'] || 'production'
      c.public.root = '/'
      c.jndi = nil
      c.ignored = %w(jndi booter)
      c
    end

    def default_jar_files
      require 'jruby-jars'
      FileList["#{@warbler_home}/lib/*.jar", JRubyJars.core_jar_path, JRubyJars.stdlib_jar_path]
    end

    def auto_detect_frameworks
      !Warbler.framework_detection || auto_detect_rails || auto_detect_merb || auto_detect_rackup
    end

    def auto_detect_rails
      return false unless task = Warbler.project_application.lookup("environment")
      task.invoke rescue nil
      return false unless defined?(::Rails)
      @dirs << "tmp" if File.directory?("tmp")
      @webxml.booter = :rails
      unless (defined?(Rails.vendor_rails?) && Rails.vendor_rails?) || File.directory?("vendor/rails")
        @gems["rails"] = Rails::VERSION::STRING
      end
      if defined?(Rails.configuration.gems)
        Rails.configuration.gems.each {|g| @gems << Gem::Dependency.new(g.name, g.requirement) }
      end
      @webxml.jruby.max.runtimes = 1 if defined?(Rails.configuration.threadsafe!)
      true
    end

    def auto_detect_merb
      return false unless task = Warbler.project_application.lookup("merb_env")
      task.invoke rescue nil
      return false unless defined?(::Merb)
      @webxml.booter = :merb
      if defined?(Merb::BootLoader::Dependencies.dependencies)
        Merb::BootLoader::Dependencies.dependencies.each {|g| @gems << g }
      else
        warn "unable to auto-detect Merb dependencies; upgrade to Merb 1.0 or greater"
      end
      true
    end

    def auto_detect_rackup
      return false unless File.exist?("config.ru")
      @webxml.booter = :rack
      @webxml.rackup = File.read("config.ru")
    end
  end

  class WebxmlOpenStruct < OpenStruct
    %w(java com org javax).each {|name| undef_method name if Object.methods.include?(name) }

    def initialize(key = 'webxml')
      @key = key
      @table = Hash.new {|h,k| h[k] = WebxmlOpenStruct.new(k) }
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

    def [](key)
      new_ostruct_member(key)
      send(key)
    end

    def []=(key, value)
      new_ostruct_member(key)
      send("#{key}=", value)
    end

    def context_params
      require 'cgi'
      params = {}
      @table.each do |k,v|
        case v
        when WebxmlOpenStruct
          nested_params = v.context_params
          nested_params.each do |nk,nv|
            params["#{CGI::escapeHTML(k.to_s)}.#{nk}"] = nv
          end
        else
          params[CGI::escapeHTML(k.to_s)] = CGI::escapeHTML(v.to_s)
        end
      end
      params.delete_if {|k,v| ['ignored', *ignored].include?(k.to_s) }
      params
    end

    def to_s
      "No value for '#@key' found"
    end
  end
end
