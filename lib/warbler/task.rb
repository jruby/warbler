#--
# Copyright (c) 2010 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'rake'
require 'rake/tasklib'
require 'stringio'
require 'zip/zip'

module Warbler
  # Warbler Rake task.  Allows defining multiple configurations inside the same
  # Rakefile by using different task names.
  #
  # To define multiple Warbler configurations in a single project, use
  # code like the following in a Rakefile:
  #
  #     Warbler::Task.new("war1", Warbler::Config.new do |config|
  #       config.war_name = "war1"
  #       # ...
  #     end
  #     Warbler::Task.new("war2", Warbler::Config.new do |config|
  #       config.war_name = "war2"
  #       # ...
  #     end
  #
  # With this setup, you can create two separate war files two
  # different configurations by running <tt>rake war1 war2</tt>.
  class Task < Rake::TaskLib
    # Task name
    attr_accessor :name

    # Warbler::Config
    attr_accessor :config

    # Warbler::War
    attr_accessor :war

    def initialize(name = :war, config = nil)
      @name   = name
      @config = config
      if @config.nil? && File.exists?(Config::FILE)
        @config = eval(File.open(Config::FILE) {|f| f.read})
      end
      @config ||= Config.new
      unless @config.kind_of? Config
        warn "Warbler::Config not provided by override in initializer or #{Config::FILE}; using defaults"
        @config = Config.new
      end
      @war = Warbler::War.new
      yield self if block_given?
      define_tasks
    end

    private
    def define_tasks
      define_main_task
      namespace name do
        define_clean_task
        define_files_task
        define_gemjar_task
        define_jar_task
        define_debug_task
      end
    end

    def define_main_task
      desc "Create the project .war file"
      task @name do
        # Invoke this way so custom dependencies can be defined before
        # the file find routine is run
        ["#{@name}:files", "#{@name}:jar"].each do |t|
          Rake::Task[t].invoke
        end
      end
    end

    def define_clean_task
      desc "Remove the .war file"
      task "clean" do
        rm_f "#{config.war_name}.war"
      end
      task "clear" => "#{name}:clean"
    end

    def define_files_task
      task "files" do
        war.apply(config)
      end
    end

    def define_gemjar_task
      gem_jar = Warbler::War.new
      task "gemjar" => "files" do
        gem_path = Regexp::quote(config.relative_gem_path)
        gems = war.files.select{|k,v| k =~ %r{#{gem_path}/} }
        gems.each do |k,v|
          gem_jar.files[k.sub(%r{#{gem_path}/}, '')] = v
        end
        war.files["WEB-INF/lib/gems.jar"] = "tmp/gems.jar"
        war.files.reject!{|k,v| k =~ /#{gem_path}/ }
        mkdir_p "tmp"
        gem_jar.create("tmp/gems.jar")
      end
    end

    def define_jar_task
      task "jar" do
        war.create(config)
      end
    end

    def define_debug_task
      desc "Dump diagnostic information"
      task "debug" => "files" do
        require 'yaml'
        puts YAML::dump(config)
        war.files.each {|k,v| puts "#{k} -> #{String === v ? v : '<blob>'}"}
      end
      task "debug:includes" => "files" do
        puts "", "included files:"
        puts *war.webinf_filelist.include
      end
      task "debug:excludes" => "files" do
        puts "", "excluded files:"
        puts *war.webinf_filelist.exclude
      end
    end
  end
end
