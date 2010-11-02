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
        define_compiled_task
        define_files_task
        define_jar_task
        define_debug_task
        define_gemjar_task
        define_config_task
        define_pluginize_task
        define_executable_task
        define_version_task
      end
    end

    def define_main_task
      desc "Create the project .war file"
      task @name do
        unless @config.features.empty?
          @config.features.each do |feature|
            t = "#@name:#{feature}"
            unless Rake.application.lookup(t)
              warn "unknown feature `#{feature}', ignoring"
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
      desc "Remove the .war file"
      task "clean" do
        rm_f "#{config.war_name}.war"
      end
      task "clear" => "#{name}:clean"
    end

    def define_compiled_task
      task "compiled" do
        war.compile(config)
      end
    end

    def define_files_task
      task "files" do
        war.apply(config)
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

    def define_gemjar_task
      task "gemjar" do
        task "#@name:jar" => "#@name:make_gemjar"
      end

      gem_jar = Warbler::War.new
      task "make_gemjar" => "files" do
        gem_path = Regexp::quote(config.relative_gem_path)
        gems = war.files.select{|k,v| k =~ %r{#{gem_path}/} }
        gems.each do |k,v|
          gem_jar.files[k.sub(%r{#{gem_path}/}, '')] = v
        end
        war.files["WEB-INF/lib/gems.jar"] = "tmp/gems.jar"
        war.files.reject!{|k,v| k =~ /#{gem_path}/ }
        mkdir_p "tmp"
        gem_jar.add_manifest
        gem_jar.create("tmp/gems.jar")
      end
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
        if !Dir["vendor/plugins/warbler*"].empty? && ENV["FORCE"].nil?
          puts "I found an old nest in vendor/plugins; please trash it so I can make a new one"
          puts "(directory vendor/plugins/warbler* exists)"
        else
          rm_rf FileList["vendor/plugins/warbler*"], :verbose => false
          mkdir_p "vendor/plugins/warbler/tasks"
          File.open("vendor/plugins/warbler/tasks/warbler.rake", "w") do |f|
            f.puts "require 'warbler'"
            f.puts "Warbler::Task.new"
          end
        end
      end
    end

    def define_executable_task
      winstone_type = ENV["WINSTONE"] || "winstone-lite"
      winstone_version = ENV["WINSTONE_VERSION"] || "0.9.10"
      winstone_path = "net/sourceforge/winstone/#{winstone_type}/#{winstone_version}/#{winstone_type}-#{winstone_version}.jar"
      winstone_jar = File.expand_path("~/.m2/repository/#{winstone_path}")
      file winstone_jar do |t|
        # Not always covered in tests as these lines may not get
        # executed every time if the jar is cached.
        puts "Downloading #{winstone_type}.jar" #:nocov:
        mkdir_p File.dirname(t.name)            #:nocov:
        require 'open-uri'                      #:nocov:
        maven_repo = ENV["MAVEN_REPO"] || "http://repo2.maven.org/maven2" #:nocov:
        open("#{maven_repo}/#{winstone_path}") do |stream| #:nocov:
          File.open(t.name, "wb") do |f|  #:nocov:
            while buf = stream.read(4096) #:nocov:
              f << buf                    #:nocov:
            end                           #:nocov:
          end                             #:nocov:
        end                               #:nocov:
      end

      task "executable" => winstone_jar do
        war.files['META-INF/MANIFEST.MF'] = StringIO.new(War::DEFAULT_MANIFEST.chomp + "Main-Class: Main\n")
        war.files['Main.class'] = Zip::ZipFile.open("#{WARBLER_HOME}/lib/warbler_jar.jar") do |zf|
          zf.get_input_stream('Main.class') {|io| StringIO.new(io.read) }
        end
        war.files['WEB-INF/winstone.jar'] = winstone_jar
      end
    end

    def define_version_task
      task "version" do
        puts "Warbler version #{Warbler::VERSION}"
      end
    end
  end
end
