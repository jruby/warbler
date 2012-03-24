#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'rake'
require 'rake/tasklib'
require 'warbler/config'
require 'warbler/jar'

module Warbler
  # Warbler Rake task.  Allows defining multiple configurations inside the same
  # Rakefile by using different task names.
  #
  # To define multiple Warbler configurations in a single project, use
  # code like the following in a Rakefile:
  #
  #     Warbler::Task.new("war1", Warbler::Config.new do |config|
  #       config.jar_name = "war1"
  #       # ...
  #     end
  #     Warbler::Task.new("war2", Warbler::Config.new do |config|
  #       config.jar_name = "war2"
  #       # ...
  #     end
  #
  # With this setup, you can create two separate war files two
  # different configurations by running <tt>rake war1 war2</tt>.
  class Task < Rake::TaskLib
    include RakeHelper

    # Task name
    attr_accessor :name

    # Warbler::Config
    attr_accessor :config

    # Warbler::Jar
    attr_accessor :jar

    def initialize(name = nil, config = nil)
      @config = config
      if @config.nil? && File.exists?(Config::FILE)
        @config = eval(File.read(Config::FILE), binding, Config::FILE, 0)
      end
      @config ||= Config.new
      unless @config.kind_of? Config
        $stderr.puts "Warbler::Config not provided by override in initializer or #{Config::FILE}; using defaults"
        @config = Config.new
      end
      @name = name || @config.jar_extension
      @jar = Warbler::Jar.new
      yield self if block_given?
      define_tasks
    end

    # Deprecated: attr_accessor :war
    alias war jar

    private
    def define_tasks
      define_main_task
      namespace name do
        define_clean_task
        define_compiled_task
        define_files_task
        define_jar_task
        define_debug_task
        define_config_task
        define_pluginize_task
        define_version_task
        define_extra_tasks
      end
    end

    def define_main_task
      desc "Create the project #{config.jar_extension} file"
      task @name do
        unless @config.features.empty?
          @config.features.each do |feature|
            t = "#@name:#{feature}"
            unless Rake.application.lookup(t)
              $stderr.puts "unknown feature `#{feature}', ignoring"
              next
            end
            Rake::Task[t].invoke
          end
        end
        # Invoke this way so custom dependencies can be defined before
        # the file find routine is run
        ["#{@name}:files", "#{@name}:jar"].each do |t|
          Rake::Task[t].invoke
        end
      end
    end

    def define_clean_task
      desc "Remove the project #{config.jar_extension} file"
      task "clean" do
        rm_f "#{config.jar_name}.#{config.jar_extension}"
      end
      task "clear" => "#{name}:clean"
    end

    def define_compiled_task
      task "compiled" do
        jar.compile(config)
        task @name do
          rm_f config.compiled_ruby_files.map {|f| f.sub(/\.rb$/, '.class') }
        end
      end
    end

    def define_files_task
      task "files" do
        jar.apply(config)
      end
    end

    def define_jar_task
      task "jar" do
        jar.create(config)
      end
    end

    def define_debug_task
      desc "Dump diagnostic information"
      task "debug" => "files" do
        require 'yaml'
        puts config.dump
        jar.files.each {|k,v| puts "#{k} -> #{String === v ? v : '<blob>'}"}
      end
      task "debug:includes" => "files" do
        puts "", "included files:"
        puts *war.app_filelist.include
      end
      task "debug:excludes" => "files" do
        puts "", "excluded files:"
        puts *war.app_filelist.exclude
      end
    end

    def define_extra_tasks
      @config.define_tasks
    end

    def define_config_task
      task "config" do
        if File.exists?(Warbler::Config::FILE) && ENV["FORCE"].nil?
          puts "There's another bird sitting on my favorite branch"
          puts "(file '#{Warbler::Config::FILE}' already exists. Pass argument FORCE=1 to override)"
        elsif !File.directory?("config")
          puts "I'm confused; my favorite branch is missing"
          puts "(directory 'config' is missing)"
        else
          cp "#{Warbler::WARBLER_HOME}/warble.rb", Warbler::Config::FILE
        end
      end
    end

    def define_pluginize_task
      task "pluginize" do
        if !Dir["lib/tasks/warbler*"].empty? && ENV["FORCE"].nil?
          puts "I found an old nest in lib/tasks; please trash it so I can make a new one"
          puts "(directory lib/tasks/warbler* exists)"
        else
          rm_rf FileList["lib/tasks/warbler*"], :verbose => false
          mkdir_p "lib/tasks/warbler"
          File.open("lib/tasks/warbler/warbler.rake", "w") do |f|
            f.puts "require 'warbler'"
            f.puts "Warbler::Task.new"
          end
        end
      end
    end

    def define_version_task
      task "version" do
        puts "Warbler version #{Warbler::VERSION}"
      end
    end
  end
end
