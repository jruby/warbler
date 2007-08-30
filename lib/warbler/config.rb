# (c) Copyright 2007 Nick Sieger <nicksieger@gmail.com>
# See the file LICENSES.txt included with the distribution for
# software license details.

require 'ostruct'

module Warbler
  # Warbler assembly configuration.
  class Config
    TOP_DIRS = %w(app config lib log vendor tmp)

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

    # Public HTML directory file list, to be copied into the root of the war
    attr_accessor :public_html

    # Name of war file (without the .war), defaults to the directory name containing
    # the Rails application
    attr_accessor :war_name

    # Extra configuration for web.xml/goldspike
    attr_accessor :webxml

    def initialize
      @staging_dir = "tmp/war"
      @dirs        = TOP_DIRS
      @includes    = FileList[]
      @excludes    = FileList["#{WARBLER_HOME}/**/*"]
      @java_libs   = FileList["#{WARBLER_HOME}/lib/*.jar"]
      @gems        = []
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

    private
    def default_webxml_config
      c = OpenStruct.new
      c.standalone = true
      c.rails_env  = "production"
      c.pool       = OpenStruct.new
      c
    end
  end
end