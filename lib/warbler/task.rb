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
  class << self
    attr_writer :project_application
    def project_application
      @project_application || Rake.application
    end

    attr_accessor :framework_detection
  end
  self.framework_detection = true

  # Warbler Rake task.  Allows defining multiple configurations inside the same
  # Rakefile by using different task names.
  class Task < Rake::TaskLib
    # Task name
    attr_accessor :name

    # Warbler::Config
    attr_accessor :config

    # Whether to print a line when a file or directory task is declared; helps
    # to see what is getting included
    attr_accessor :verbose

    def initialize(name = :war, config = nil, tasks = :define_tasks)
      @name   = name
      @config = config
      if @config.nil? && File.exists?(Config::FILE)
        @config = eval(File.open(Config::FILE) {|f| f.read})
      end
      @config ||= Config.new
      unless @config.kind_of? Config
        warn "War::Config not provided by override in initializer or #{Config::FILE}; using defaults"
        @config = Config.new
      end
      yield self if block_given?
      send tasks
    end

    private
    def define_tasks
      define_main_task
      define_clean_task
      define_public_task
      define_gems_task
      define_webxml_task
      define_app_task
      define_jar_task
      define_debug_task
    end

    def define_main_task
      desc "Create #{@config.war_name}.war"
      task @name => ["#{@name}:app", "#{@name}:public", "#{@name}:webxml", "#{@name}:jar"]
    end

    def define_clean_task
      with_namespace_and_config do |name, config|
        desc "Clean up the .war file"
        task "clean" do
          rm_f "#{config.war_name}.war"
        end
        task "clear" => "#{name}:clean"
      end
    end

    def define_public_task
      public_target_files = nil
      with_namespace_and_config do
        desc "Collect all public HTML files to be placed in the root of the .war"
        task "public" do
          public_target_files = find_public_files
        end
        task "debug:public" => "public"do
          puts "", "public files:"
          puts *public_target_files
        end
      end
    end

    def define_gems_task
      targets = nil
      with_namespace_and_config do
        desc "Look for gems to package into WEB-INF/gems"
        task "gems" do
          targets = find_gems_files
        end
        task "debug:gems" => "gems "do
          puts "", "gems files:"
          puts *targets
        end
      end
    end

    def define_webxml_task
      with_namespace_and_config do |name, config|
        desc "Generate a web.xml file for the webapp"
        task "webxml" do
          webxml = nil
          if File.exist?("config/web.xml")
            webxml = "config/web.xml"
          else
            erb = if File.exist?("config/web.xml.erb")
              "config/web.xml.erb"
            else
              "#{WARBLER_HOME}/web.xml.erb"
            end
            require 'erb'
            erb = ERB.new(File.open(erb) {|f| f.read })
            webxml = StringIO.new(erb.result(erb_binding(config.webxml)))
          end
          config.add_file("WEB-INF/web.xml", webxml)
        end
      end
    end

    def define_java_libs_task
      target_files = nil
      with_namespace_and_config do |name, config|
        desc "Collect all java libraries for the .war"
        task "java_libs" do
          target_files = find_java_libs
        end
        task "debug:java_libs" => "java_libs" do
          puts "", "java_libs files:"
          puts *target_files
        end
      end
    end

    def find_java_libs
      @config.java_libs.map do |lib|
        @config.add_file(apply_pathmaps(lib, :java_libs), lib)
      end
    end

    def define_java_classes_task
      target_files = nil
      with_namespace_and_config do |name, config|
        desc "Collect java classes for the .war"
        task "java_classes" do
          target_files = find_java_classes
        end
        task "debug:java_classes" => "java_classes" do
          puts "", "java_classes files:"
          puts *target_files
        end
      end
      target_files
    end

    def find_java_classes
      @config.java_classes.map do |f|
        @config.add_file(apply_pathmaps(f, :java_classes), f)
      end
    end

    def define_app_task
      webinf_target_files = nil
      with_namespace_and_config do |name, config|
        desc "Collect all application files for the .war"
        task "app" do
          webinf_target_files = find_webinf_files
        end
        task "debug:app" => "app" do
          puts "", "app files:"
          puts *webinf_target_files
        end
      end
    end

    def define_jar_task
      with_namespace_and_config do |name, config|
        desc "Create the .war"
        task "jar" do
          if config.manifest_file
            config.add_file 'META-INF/MANIFEST.MF', config.manifest_file
          end
          war_path = "#{config.war_name}.war"
          war_path = File.join(config.autodeploy_dir, war_path) if config.autodeploy_dir
          create_war war_path, config.files
        end
      end
    end

    def define_debug_task
      with_namespace_and_config do |name, config|
        task "debug" do
          require 'yaml'
          puts YAML::dump(config)
        end
        all_debug_tasks = %w(: app java_libs java_classes gems public includes excludes).map do |n|
          n.sub(/^:?/, "#{name}:debug:").sub(/:$/, '')
        end
        task "debug:all" => all_debug_tasks
      end
    end

    def find_public_files
      @config.public_html.map do |f|
        @config.add_file apply_pathmaps(f, :public_html), f
      end
    end

    def find_webinf_files
      target_files = @config.dirs.select do |d|
        exists = File.directory?(d)
        warn "warning: application directory `#{d}' does not exist or is not a directory; skipping" unless exists
        exists
      end.map do |d|
        @config.add_file apply_pathmaps(d, :application), nil
      end
      files = FileList[*(@config.dirs.map{|d| "#{d}/**/*"})]
      files.include *(@config.includes.to_a)
      files.exclude *(@config.excludes.to_a)
      target_files += files.map do |f|
        @config.add_file apply_pathmaps(f, :application), f
      end
      target_files += find_java_libs
      target_files += find_java_classes
      task "#@name:debug:includes" do
        puts "", "included files:"
        puts *files.include
      end
      task "#@name:debug:excludes" do
        puts "", "excluded files:"
        puts *files.exclude
      end
      target_files
    end

    def with_namespace_and_config
      name, config = @name, @config
      namespace name do
        yield name, config
      end
    end

    def find_gems_files
      files = []
      @config.gems.each do |gem, version|
        find_single_gem_files(gem, files, version)
      end
      files
    end

    def find_single_gem_files(gem_pattern, targets, version = nil)
      gem = case gem_pattern
      when Gem::Dependency
        gem_pattern
      else
        Gem::Dependency.new(gem_pattern, Gem::Requirement.create(version))
      end

      # skip development dependencies
      return if gem.respond_to?(:type) and gem.type != :runtime

      matched = Gem.source_index.search(gem)
      fail "gem '#{gem}' not installed" if matched.empty?
      spec = matched.last

      # skip gems with no load path
      return if spec.loaded_from == ""

      targets << @config.add_file(apply_pathmaps(spec.loaded_from, :gemspecs), spec.loaded_from)
      spec.files.each do |f|
        src = File.join(spec.full_name, f)
        targets << @config.add_file(apply_pathmaps(src, :gems), src)
      end

      if @config.gem_dependencies
        spec.dependencies.each do |dep|
          find_single_gem_files(dep, targets)
        end
      end
    end

    def erb_binding(webxml)
      binding
    end

    def apply_pathmaps(file, pathmaps)
      pathmaps = @config.pathmaps.send(pathmaps)
      pathmaps.each do |p|
        file = file.pathmap(p)
      end if pathmaps
      file
    end

    def create_war(war_file, entries)
      rm_f(war_file)
      Zip::ZipFile.open(war_file, Zip::ZipFile::CREATE) do |zipfile|
        entries.keys.sort.each do |entry|
          src = entries[entry]
          case src
          when nil
            zipfile.mkdir(entry)
          when IO
            zipfile.get_output_stream(entry) {|f| f << src.read }
          else
            zipfile.add(entry, src)
          end
        end
      end
    rescue => e
      puts "PWD: #{Dir.getwd}"
      puts e, *e.backtrace
      raise
    end
  end
end
