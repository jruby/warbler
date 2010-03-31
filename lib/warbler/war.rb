module Warbler
  class War
    attr_reader :files
    attr_reader :webinf_filelist

    def initialize
      @files = {}
    end

    def apply(config)
      find_webinf_files(config)
      find_java_libs(config)
      find_java_classes(config)
      find_gems_files(config)
      find_public_files(config)
      add_webxml(config)
      add_manifest(config)
      add_bundler_files(config)
    end

    def create(config_or_path)
      war_path = config_or_path
      if Warbler::Config === config_or_path
        war_path = "#{config_or_path.war_name}.war"
        war_path = File.join(config_or_path.autodeploy_dir, war_path) if config_or_path.autodeploy_dir
      end
      rm_f war_path
      ensure_directory_entries
      puts "Creating #{war_path}"
      create_war war_path, @files
    end

    def add_webxml(config)
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
      @files["WEB-INF/web.xml"] = webxml
    end

    def add_manifest(config)
      if config.manifest_file
        @files['META-INF/MANIFEST.MF'] = config.manifest_file
      else
        @files['META-INF/MANIFEST.MF'] = StringIO.new(%{Manifest-Version: 1.0\nCreated-By: Warbler #{VERSION}\n\n})
      end
    end

    def find_java_libs(config)
      config.java_libs.map {|lib| add_with_pathmaps(config, lib, :java_libs) }
    end

    def find_java_classes(config)
      config.java_classes.map {|f| add_with_pathmaps(config, f, :java_classes) }
    end

    def find_public_files(config)
      config.public_html.map {|f| add_with_pathmaps(config, f, :public_html) }
    end

    def find_gems_files(config)
      config.gems.each {|gem, version| find_single_gem_files(config, gem, version) }
    end

    def find_single_gem_files(config, gem_pattern, version = nil)
      if Gem::Specification === gem_pattern
        spec = gem_pattern
      else
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
      end

      # skip gems with no load path
      return if spec.loaded_from == ""

      add_with_pathmaps(config, spec.loaded_from, :gemspecs)
      spec.files.each do |f|
        src = File.join(spec.full_gem_path, f)
        # some gemspecs may have incorrect file listings
        next unless File.exist?(src)
        @files[apply_pathmaps(config, File.join(spec.full_name, f), :gems)] = src
      end

      if config.gem_dependencies
        spec.dependencies.each do |dep|
          find_single_gem_files(config, dep)
        end
      end
    end

    def find_webinf_files(config)
      config.dirs.select do |d|
        exists = File.directory?(d)
        warn "warning: application directory `#{d}' does not exist or is not a directory; skipping" unless exists
        exists
      end.each do |d|
        @files[apply_pathmaps(config, d, :application)] = nil
      end
      @webinf_filelist = FileList[*(config.dirs.map{|d| "#{d}/**/*"})]
      @webinf_filelist.include *(config.includes.to_a)
      @webinf_filelist.exclude *(config.excludes.to_a)
      @webinf_filelist.map {|f| add_with_pathmaps(config, f, :application) }
    end

    def add_bundler_files(config)
      if config.bundler
        @files[apply_pathmaps(config, 'Gemfile', :application)] = 'Gemfile'
        @files[apply_pathmaps(config, '.bundle/environment.rb', :application)] = '.bundle/war-environment.rb'
      end
    end

    private
    def add_with_pathmaps(config, f, map_type)
      @files[apply_pathmaps(config, f, map_type)] = f
    end

    def erb_binding(webxml)
      binding
    end

    def apply_pathmaps(config, file, pathmaps)
      pathmaps = config.pathmaps.send(pathmaps)
      pathmaps.each do |p|
        file = file.pathmap(p)
      end if pathmaps
      file
    end

    def ensure_directory_entries
      files.select {|k,v| !v.nil? }.each do |k,v|
        dir = File.dirname(k)
        while dir != "." && !files.has_key?(dir)
          files[dir] = nil
          dir = File.dirname(dir)
        end
      end
    end

    def create_war(war_file, entries)
      Zip::ZipFile.open(war_file, Zip::ZipFile::CREATE) do |zipfile|
        entries.keys.sort.each do |entry|
          src = entries[entry]
          if src.respond_to?(:read)
            zipfile.get_output_stream(entry) {|f| f << src.read }
          elsif src.nil? || File.directory?(src)
            zipfile.mkdir(entry)
          else
            zipfile.add(entry, src)
          end
        end
      end
    end

    # Java-boosted war creation for JRuby; replaces #create_war with Java version
    require 'warbler_war' if defined?(JRUBY_VERSION)
  end
end
