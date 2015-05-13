#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'warbler/zip_support'
require 'stringio'
require 'pathname'

module Warbler
  # Class that holds the files that will be stored in the jar file.
  # The #files attribute contains a hash of pathnames inside the jar
  # file to their contents. Contents can be one of:
  # * +nil+ representing a directory entry
  # * Any object responding to +read+ representing an in-memory blob
  # * A String filename pointing to a file on disk
  class Jar
    include PathmapHelper
    include RakeHelper
    include PlatformHelper

    DEFAULT_MANIFEST = %{Manifest-Version: 1.0\nCreated-By: Warbler #{Warbler::VERSION}\n\n}

    attr_reader :files
    attr_reader :app_filelist

    def initialize
      @files = {}
    end

    def contents(entry)
      file = files[entry]
      file.respond_to?(:read) ? file.read : File.open(file) {|f| f.read }
    end

    def compile(config)
      find_gems_files(config)
      # Compiling all Ruby files we can find -- do we need to allow an
      # option to configure what gets compiled?
      return if (config.compiled_ruby_files.nil? || config.compiled_ruby_files.empty?) && files.empty?

      if config.compile_gems
        ruby_files = gather_all_rb_files(config)
        run_javac(config, ruby_files.values)
        replace_compiled_ruby_files_and_gems(config, ruby_files)
      else
        compiled_ruby_files = config.compiled_ruby_files - config.excludes.to_a
        run_javac(config, compiled_ruby_files)
        replace_compiled_ruby_files(config, compiled_ruby_files)
      end
    end

    def run_javac(config, compiled_ruby_files)
      if config.webxml && config.webxml.context_params.has_key?('jruby.compat.version')
        compat_version = "--#{config.webxml.jruby.compat.version}"
      else
        compat_version = ''
      end

      compiled_ruby_files.each_slice(2500) do |slice|
        # Need to use the version of JRuby in the application to compile it
        javac_cmd = %Q{java -classpath #{config.java_libs.join(File::PATH_SEPARATOR)} #{java_version(config)} org.jruby.Main #{compat_version} -S jrubyc \"#{slice.join('" "')}\"}
        if which('java').nil? && which('env')
          system %Q{env -i #{javac_cmd}}
        else
          system javac_cmd
        end
        raise "Compile failed" if $?.exitstatus > 0
      end
      @compiled = true
    end

    def java_version(config)
      config.bytecode_version ? "-Djava.specification.version=#{config.bytecode_version}" : ''
    end

    def replace_compiled_ruby_files(config, compiled_ruby_files)
      # Exclude the rb files and recreate them. This
      # prevents the original contents being used.
      config.excludes += compiled_ruby_files

      compiled_ruby_files.each do |ruby_source|
        files[apply_pathmaps(config, ruby_source, :application)] = StringIO.new("load __FILE__.sub(/\.rb$/, '.class')")
      end
    end

    def replace_compiled_ruby_files_and_gems(config, compiled_ruby_files)
      # Exclude the rb files and recreate them. This
      # prevents the original contents being used.
      config.excludes += compiled_ruby_files.keys

      compiled_ruby_files.each do |inside_jar, file_system_location|
        # The gems are already inside the gems folder inside the jar, however when using the :gems pathmap, they will
        # get put into the gems/gems folder, to prevent this we chop off the first gems folder directory
        inside_jar = inside_jar.dup
        if inside_jar.split(File::SEPARATOR).first == 'gems'
          inside_jar = inside_jar.split(File::SEPARATOR)[1..-1].join(File::SEPARATOR)
          pathmap = :gems
        else
          pathmap = :application
        end
        files[apply_pathmaps(config, inside_jar, pathmap)] = StringIO.new("load __FILE__.sub(/\.rb$/, '.class')")
        files[apply_pathmaps(config, inside_jar.sub(/\.rb$/, '.class'), pathmap)] = file_system_location.sub(/\.rb$/, '.class')
      end
    end

    #
    def gather_all_rb_files(config)
      FileUtils.mkdir_p('tmp')
      # Gather all the files in the files list and copy them to the tmp directory
      gems_to_compile = files.select {|k, f| !f.is_a?(StringIO) && f =~ /\.rb$/ }
      # 1.8.7 Support, convert back to hash
      if gems_to_compile.is_a?(Array)
        gems_to_compile = gems_to_compile.inject({}) {|h,z| h.merge!(z[0] => z[1]) }
      end
      gems_to_compile.each do |jar_file, rb|
        FileUtils.mkdir_p(File.dirname(File.join('tmp', jar_file)))
        new_rb = File.join('tmp', jar_file)
        FileUtils.copy(rb, new_rb)
        gems_to_compile[jar_file] = new_rb
      end
      # Gather all the application files which the user wrote (not dependencies)
      main_files_to_compile = config.compiled_ruby_files - config.excludes.to_a
      main_files_to_compile.each do |f|
        FileUtils.mkdir_p(File.dirname(File.join('tmp', f)))
        FileUtils.copy(f, File.join('tmp', f))
      end
      main_files_to_compile = main_files_to_compile.inject({}) {|h,f| h.merge!(f => f) }
      files.keys.each do |k|
        # Update files list to point to the temporary file
        files[k] = gems_to_compile[k] || main_files_to_compile[k] || files[k]
      end
      main_files_to_compile.merge(gems_to_compile)
    end

    # Apply the information in a Warbler::Config object in order to
    # look for files to put into this war file.
    def apply(config)
      find_application_files(config)
      find_java_libs(config)
      find_java_classes(config)
      find_gems_files(config)
      add_manifest(config)
      add_init_file(config)
      add_script_files(config)
      apply_traits(config)
    end

    # Create the jar or war file. The single argument can either be a
    # Warbler::Config or a filename of the file to create.
    def create(config_or_path)
      path = config_or_path
      if Warbler::Config === config_or_path
        path = "#{config_or_path.jar_name}.#{config_or_path.jar_extension}"
        path = File.join(config_or_path.autodeploy_dir, path) if config_or_path.autodeploy_dir
      end
      rm_f path
      ensure_directory_entries
      puts "Creating #{path}"
      if Warbler::Config === config_or_path
        @files.delete("#{config_or_path.jar_name}/#{path}")
      end
      create_jar path, @files
    end

    # Invoke a hook to allow the project traits to add or modify the archive contents.
    def apply_traits(config)
      config.update_archive(self)
    end

    # Add a manifest file either from config or by making a default manifest.
    def add_manifest(config = nil)
      unless @files.keys.detect{|k| k =~ /^META-INF\/MANIFEST\.MF$/i}
        if config && config.manifest_file
          @files['META-INF/MANIFEST.MF'] = config.manifest_file
        else
          @files['META-INF/MANIFEST.MF'] = StringIO.new(DEFAULT_MANIFEST)
        end
      end
    end

    # Add java libraries to WEB-INF/lib.
    def find_java_libs(config)
      config.java_libs.map {|lib| add_with_pathmaps(config, lib, :java_libs) }
    end

    # Add java classes to WEB-INF/classes.
    def find_java_classes(config)
      config.java_classes.map {|f| add_with_pathmaps(config, f, :java_classes) }
    end

    # Add gems to WEB-INF/gems
    def find_gems_files(config)
      unless @compiled and config.compile_gems
        config.gems.specs(config.gem_dependencies).each {|spec| find_single_gem_files(config, spec) }
      end
    end

    # Add a single gem to WEB-INF/gems
    def find_single_gem_files(config, spec)
      full_gem_path = Pathname.new(spec.full_gem_path)

      # skip gems whose full_gem_path does not exist
      ($stderr.puts "warning: skipping #{spec.name} (#{full_gem_path.to_s} does not exist)" ; return) unless full_gem_path.exist?

      @files[apply_pathmaps(config, "#{spec.full_name}.gemspec", :gemspecs)] = StringIO.new(spec.to_ruby)
      FileList["#{full_gem_path.to_s}/**/*"].each do |src|
        f = Pathname.new(src).relative_path_from(full_gem_path).to_s
        next if config.gem_excludes && config.gem_excludes.any? {|rx| f =~ rx }
        @files[apply_pathmaps(config, File.join(spec.full_name, f), :gems)] = src
      end
    end

    # Add all application directories and files to the archive.
    def find_application_files(config)
      config.dirs.select do |d|
        exists = File.directory?(d)
        $stderr.puts "warning: application directory `#{d}' does not exist or is not a directory; skipping" unless exists
        exists
      end.each do |d|
        @files[apply_pathmaps(config, d, :application)] = nil
      end
      @app_filelist = FileList[*(config.dirs.map{|d| %W{#{d}/**/*/**/* #{d}/*}}.flatten)]
      @app_filelist.include *(config.includes.to_a)
      @app_filelist.exclude *(config.excludes.to_a)
      @app_filelist.map {|f| add_with_pathmaps(config, f, :application) }
    end

    # Add init.rb file to the war file.
    def add_init_file(config)
      if config.init_contents
        contents = ''
        config.init_contents.each do |file|
          if file.respond_to?(:read)
            contents << file.read
          elsif File.extname(file) == '.erb'
            contents << expand_erb(file, config).read
          else
            contents << File.read(file)
          end
        end
        @files[config.init_filename] = StringIO.new(contents)
      end
    end

    def add_script_files(config)
      config.script_files.each do |file|
        @files["META-INF/#{File.basename(file)}"] = StringIO.new(File.read(file))
      end
    end

    def add_with_pathmaps(config, f, map_type)
      @files[apply_pathmaps(config, f, map_type)] = f
    end

    def expand_erb(file, config)
      require 'erb'
      erb = ERB.new(File.open(file) {|f| f.read })
      StringIO.new(erb.result(erb_binding(config)))
    end

    def erb_binding(config)
      webxml = config.webxml
      binding
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

    def create_jar(jar_path, entries)
      ZipSupport.create(jar_path) do |zipfile|
        entries.keys.sort.each do |entry|
          src = entries[entry]
          if src.respond_to?(:read)
            zipfile.get_output_stream(entry) {|f| f << src.read }
          elsif src.nil? || File.directory?(src)
            if File.symlink?(entry) && ! defined?(JRUBY_VERSION)
              $stderr.puts "directory symlinks are not followed unless using JRuby; " +
                           "#{entry.inspect} contents not in archive"
            end
            zipfile.mkdir(entry.dup) # in case it's frozen rubyzip 0.9.6.1 workaround
          elsif File.symlink?(src)
            zipfile.get_output_stream(entry) { |f| f << File.read(src) }
          elsif File.exist?(src)
            zipfile.add(entry, src)
          else
            $stderr.puts "File not found; #{entry.inspect} not in archive"
          end
        end
      end
    end

    def entry_in_jar(jar, entry)
      ZipSupport.open(jar) do |zf|
        zf.get_input_stream(entry) {|io| StringIO.new(io.read) }
      end
    end

    # Java-boosted jar creation for JRuby; replaces #create_jar and
    # #entry_in_jar with Java version
    require 'warbler_jar' if defined?(JRUBY_VERSION) && JRUBY_VERSION >= "1.5"
  end

  # Warbler::War is Deprecated. Please use Warbler::Jar.
  class War < Jar
    def initialize(*)
      super
      $stderr.puts "Warbler::War is deprecated. Please replace all occurrences with Warbler::Jar."
    end
  end
end
