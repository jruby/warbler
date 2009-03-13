#--
# (c) Copyright 2007-2009 Sun Microsystems, Inc.
# See the file LICENSES.txt included with the distribution for
# software license details.
#++

require 'rake'
require 'rake/tasklib'

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
    COPY_PROC = proc {|t| cp t.prerequisites.last, t.name }

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
      define_exploded_task
      define_debug_task
    end

    def define_main_task
      desc "Create #{@config.war_name}.war"
      task @name => ["#{@name}:app", "#{@name}:public", "#{@name}:webxml", "#{@name}:jar"]
    end

    def define_clean_task
      with_namespace_and_config do |name, config|
        desc "Clean up the .war file and the staging area"
        task "clean" do
          rm_rf config.staging_dir
          rm_f "#{config.war_name}.war"
        end
        task "clear" => "#{name}:clean"
      end
    end

    def define_public_task
      public_target_files = define_public_file_tasks
      with_namespace_and_config do
        desc "Copy all public HTML files to the root of the .war"
        task "public" => public_target_files
        task "debug:public" do
          puts "", "public files:"
          puts *public_target_files
        end
      end
    end

    def define_gems_task
      directory "#{config.staging_dir}/#{apply_pathmaps("sources-0.0.1.gem", :gems).pathmap("%d")}"
      targets = define_copy_gems_task
      with_namespace_and_config do
        desc "Unpack all gems into WEB-INF/gems"
        task "gems" => targets
        task "debug:gems" do
          puts "", "gems files:"
          puts *targets
        end
      end
    end

    def define_webxml_task
      with_namespace_and_config do |name, config|
        desc "Generate a web.xml file for the webapp"
        task "webxml" do
          mkdir_p "#{config.staging_dir}/WEB-INF"
          if File.exist?("config/web.xml")
            cp "config/web.xml", "#{config.staging_dir}/WEB-INF"
          else
            erb = if File.exist?("config/web.xml.erb")
              "config/web.xml.erb"
            else
              "#{WARBLER_HOME}/web.xml.erb"
            end
            require 'erb'
            erb = ERB.new(File.open(erb) {|f| f.read })
            File.open("#{config.staging_dir}/WEB-INF/web.xml", "w") do |f|
              f << erb.result(erb_binding(config.webxml))
            end
          end
        end
      end
    end

    def define_java_libs_task
      target_files = @config.java_libs.map do |lib|
        define_file_task(lib,
          "#{@config.staging_dir}/#{apply_pathmaps(lib, :java_libs)}")
      end
      with_namespace_and_config do |name, config|
        desc "Copy all java libraries into the .war"
        task "java_libs" => target_files
        task "debug:java_libs" do
          puts "", "java_libs files:"
          puts *target_files
        end
      end
      target_files
    end

    def define_java_classes_task
      target_files = @config.java_classes.map do |f|
        define_file_task(f,
          "#{@config.staging_dir}/#{apply_pathmaps(f, :java_classes)}")
      end
      with_namespace_and_config do |name, config|
        desc "Copy java classes into the .war"
        task "java_classes" => target_files
        task "debug:java_classes" do
          puts "", "java_classes files:"
          puts *target_files
        end
      end
      target_files
    end

    def define_app_task
      webinf_target_files = define_webinf_file_tasks
      with_namespace_and_config do |name, config|
        desc "Copy all application files into the .war"
        task "app" => ["#{name}:gems", *webinf_target_files]
        task "debug:app" do
          puts "", "app files:"
          puts *webinf_target_files
        end
      end
    end

    def define_jar_task
      with_namespace_and_config do |name, config|
        desc "Run the jar command to create the .war"
        task "jar" do
          war_path = "#{config.war_name}.war"
          war_path = File.join(config.autodeploy_dir, war_path) if config.autodeploy_dir
          flags, manifest = config.manifest_file ? ["cfm", config.manifest_file] : ["cf", ""]
          sh "jar #{flags} #{war_path} #{manifest} -C #{config.staging_dir} ."
        end
      end
    end

    def define_exploded_task
      with_namespace_and_config do |name,config|
        libs = define_java_libs_task
        desc "Create an exploded war in the app's public directory"
        task "exploded" => ["webxml", "java_classes", "gems", *libs] do
          cp "#{@config.staging_dir}/WEB-INF/web.xml", "."
          cp File.join(WARBLER_HOME, "sun-web.xml"), "." unless File.exists?("sun-web.xml")
          ln_sf "#{@config.staging_dir}/WEB-INF/gems", "."
          if File.directory?("#{@config.staging_dir}/WEB-INF/classes")
            ln_sf "#{@config.staging_dir}/WEB-INF/classes", "."
          end
          mkdir_p "lib"
          libs.each {|l| ln_sf l, "lib/#{File.basename(l)}"}
          ln_sf "..", "public/WEB-INF"
        end

        task "clean:exploded" do
          (libs.map {|l| "lib/#{File.basename(l)}" } +
            ["gems", "public/WEB-INF", "classes"]).each do |l|
            rm_f l if File.exist?(l) && File.symlink?(l)
          end
          rm_f "*web.xml"
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

    def define_public_file_tasks
      @config.public_html.map do |f|
        define_file_task(f, "#{@config.staging_dir}/#{apply_pathmaps(f, :public_html)}")
      end
    end

    def define_webinf_file_tasks
      target_files = @config.dirs.select do |d|
        exists = File.directory?(d)
        warn "warning: application directory `#{d}' does not exist or is not a directory; skipping" unless exists
        exists
      end.map do |d|
        define_file_task(d, "#{@config.staging_dir}/#{apply_pathmaps(d, :application)}")
      end
      files = FileList[*(@config.dirs.map{|d| "#{d}/**/*"})]
      files.include *(@config.includes.to_a)
      files.exclude *(@config.excludes.to_a)
      target_files += files.map do |f|
        define_file_task(f,
          "#{@config.staging_dir}/#{apply_pathmaps(f, :application)}")
      end
      target_files += define_java_libs_task
      target_files += define_java_classes_task
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

    def define_file_task(source, target)
      if File.directory?(source)
        directory target
        puts %{directory "#{target}"} if verbose
      else
        directory File.dirname(target)
        file(target => [File.dirname(target), source], &COPY_PROC)
        puts %{file "#{target}" => "#{source}"} if verbose
      end
      target
    end

    def with_namespace_and_config
      name, config = @name, @config
      namespace name do
        yield name, config
      end
    end

    def define_copy_gems_task
      targets = []
      @config.gems.each do |gem, version|
        define_single_gem_tasks(gem, targets, version)
      end
      targets
    end

    def define_single_gem_tasks(gem_pattern, targets, version = nil)
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

      gem_name = "#{spec.name}-#{spec.version}"
      unless spec.platform.nil? || spec.platform == Gem::Platform::RUBY
        [spec.platform, spec.original_platform].each do |p|
          name = "#{gem_name}-#{p}"
          if File.exist?(File.join(Gem.dir, 'cache', "#{name}.gem"))
            gem_name = name
            break
          end
        end
      end

      gem_unpack_task_name = "gem:#{gem_name}"
      return if Rake::Task.task_defined?(gem_unpack_task_name)

      targets << define_file_task(spec.loaded_from,
        "#{@config.staging_dir}/#{apply_pathmaps(spec.loaded_from, :gemspecs)}")

      task targets.last do
        Rake::Task[gem_unpack_task_name].invoke
      end

      src = File.join(Gem.dir, 'cache', "#{gem_name}.gem")
      dest = "#{config.staging_dir}/#{apply_pathmaps(src, :gems)}"

      task gem_unpack_task_name => [dest.pathmap("%d")] do |t|
        require 'rubygems/installer'
        Gem::Installer.new(src, :unpack => true).unpack(dest)
      end

      if @config.gem_dependencies
        spec.dependencies.each do |dep|
          define_single_gem_tasks(dep, targets)
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
  end
end
