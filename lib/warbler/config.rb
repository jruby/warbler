#--
# Copyright (c) 2010 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'set'
require 'warbler/gems'
require 'warbler/traits'

module Warbler
  # Warbler war file assembly configuration class.
  class Config
    TOP_DIRS = %w(app config lib log vendor)
    FILE = "config/warble.rb"
    BUILD_GEMS = %w(warbler rake rcov)

    include Traits

    # Features: additional options controlling how the jar is built.
    # Currently the following features are supported:
    # - gemjar: package the gem repository in a jar file in WEB-INF/lib
    # - executable: embed a web server and make the war executable
    # - compiled: compile .rb files to .class files
    attr_accessor :features

    # Traits: an array of trait classes corresponding to
    # characteristics of the project that are either auto-detected or
    # configured.
    attr_accessor :traits

    # Deprecated: No longer has any effect.
    attr_accessor :staging_dir

    # Directory where the war file will be written. Can be used to direct
    # Warbler to place your war file directly in your application server's
    # autodeploy directory. Defaults to the root of the application directory.
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

    # Rubygems to install into the webapp.
    attr_accessor :gems

    # Whether to include dependent gems (default true)
    attr_accessor :gem_dependencies

    # Array of regular expressions matching relative paths in gems to
    # be excluded from the war. Default contains no exclusions.
    attr_accessor :gem_excludes

    # Whether to exclude **/*.log files (default is true)
    attr_accessor :exclude_logs

    # Public HTML directory file list, to be copied into the root of the war
    attr_accessor :public_html

    # Container of pathmaps used for specifying source-to-destination transformations
    # under various situations (<tt>public_html</tt> and <tt>java_classes</tt> are two
    # entries in this structure).
    attr_accessor :pathmaps

    # Name of jar or war file (without the extension), defaults to the
    # directory name containing the application.
    attr_accessor :jar_name

    # Extension of jar file. Defaults to <tt>jar</tt> or <tt>war</tt> depending on the project.
    attr_accessor :jar_extension

    # Name of a MANIFEST.MF template to use.
    attr_accessor :manifest_file

    # Files for WEB-INF directory (next to web.xml). Contains web.xml by default.
    # If there are .erb files they will be processed with webxml config.
    attr_accessor :webinf_files

    # Use Bundler to locate gems if Gemfile is found. Default is true.
    attr_accessor :bundler

    # An array of Bundler groups to avoid including in the war file.
    # Defaults to ["development", "test"].
    attr_accessor :bundle_without

    # Path to the pre-bundled gem directory inside the war file. Default is '/WEB-INF/gems'.
    # This also sets 'gem.path' inside web.xml.
    attr_accessor :gem_path

    # List of ruby files to compile to class files. Default is to
    # compile all .rb files in the application.
    attr_accessor :compiled_ruby_files

    # Warbler writes an "init" file into the war at this location. JRuby-Rack and possibly other
    # launchers may use this to initialize the Ruby environment.
    attr_accessor :init_filename

    # Array containing filenames or StringIO's to be concatenated together to form the init file.
    # If the filename ends in .erb the file will be expanded the same way web.xml.erb is; see below.
    attr_accessor :init_contents

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
    # * <tt>webxml.gem.path</tt> -- the path to your bundled gem directory
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

    attr_reader :warbler_templates

    def initialize(warbler_home = WARBLER_HOME)
      super()

      @warbler_home      = warbler_home
      @warbler_templates = "#{WARBLER_HOME}/lib/warbler/templates"
      @features          = Set.new
      @dirs              = TOP_DIRS.select {|d| File.directory?(d)}
      @includes          = FileList[]
      @excludes          = FileList[]
      @java_libs         = FileList[]
      @java_classes      = FileList[]
      @gems              = Warbler::Gems.new
      @gem_dependencies  = true
      @gem_excludes      = []
      @exclude_logs      = true
      @public_html       = FileList[]
      @jar_name          = File.basename(Dir.getwd)
      @jar_extension     = 'jar'
      @webinf_files      = FileList[]
      @init_filename     = 'META-INF/init.rb'
      @init_contents     = ["#{@warbler_templates}/config.erb"]

      before_configure
      yield self if block_given?
      after_configure

      @compiled_ruby_files ||= FileList[*@dirs.map {|d| "#{d}/**/*.rb"}]

      @excludes += ["tmp/war"] if File.directory?("tmp/war")
      @excludes += warbler_vendor_excludes(warbler_home)
      @excludes += FileList["**/*.log"] if @exclude_logs
    end

    def gems=(value)
      @gems = Warbler::Gems.new(value)
    end

    def relative_gem_path
      @gem_path[1..-1]
    end

    # Deprecated
    def war_name
      warn "config.war_name deprecated; replace with config.jar_name" #:nocov:
      jar_name                  #:nocov:
    end

    # Deprecated
    def war_name=(w)
      warn "config.war_name deprecated; replace with config.jar_name" #:nocov:
      self.jar_name = w         #:nocov:
    end

    private
    def warbler_vendor_excludes(warbler_home)
      warbler = File.expand_path(warbler_home)
      if warbler =~ %r{^#{Dir.getwd}/(.*)}
        FileList["#{$1}"]
      else
        []
      end
    end

    def dump
      YAML::dump(self.dup.tap{|c| c.dump_traits })
    end
    public :dump
  end
end
