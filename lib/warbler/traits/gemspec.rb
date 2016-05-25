#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

module Warbler
  module Traits
    # The Gemspec trait reads a .gemspec file to determine the files,
    # executables, require paths, and dependencies for a project.
    class Gemspec
      include Trait
      include PathmapHelper
      include ExecutableHelper

      def self.detect?
        !Dir['*.gemspec'].empty?
      end

      def before_configure; require 'yaml'
        @spec_file = Dir['*.gemspec'].first
        @spec = File.open(@spec_file) { |f| Gem::Specification.from_yaml(f) } rescue Gem::Specification.load(@spec_file)
        @spec.runtime_dependencies.each { |g| config.gems << g }
        config.dirs = []
        config.compiled_ruby_files = @spec.files.select { |f| f =~ /\.rb$/ }
      end

      def after_configure
        @spec.require_paths.each do |p|
          add_init_load_path( config.pathmaps.application.inject(p) { |pm,x| pm.pathmap(x) } )
        end
      end

      def update_archive(jar)
        @spec.files.each do |f|
          unless File.exist?(f)
            warn "update your gemspec; skipping missing file #{f}"
            next
          end
          file_key = jar.apply_pathmaps(config, f, :application)
          next if jar.files[file_key]
          jar.files[file_key] = f
        end

        config.compiled_ruby_files.each do |f|
          f = f.sub(/\.rb$/, '.class')
          next unless File.exist?(f)
          jar.files[apply_pathmaps(config, f, :application)] = f
        end

        update_archive_add_executable(jar)
      end

      def default_executable
        if ! @spec.executables.empty?
          exe_script = @spec.executables.first
          exe_path = File.join(@spec.bindir, exe_script) # bin/script
          if File.exists?(exe_path)
            exe_path
          elsif File.exists?("bin/#{exe_script}") # compatibility
            "bin/#{exe_script}" # ... should probably remove this
          else
            raise "no `#{exe_script}` executable script found"
          end
        elsif exe_path = Dir['bin/*'].sort.first
          warn "no executables found in #{@spec_file}, using #{exe_path}"
          exe_path
        elsif exe_path = Dir['exe/*'].sort.first
          warn "no executables found in #{@spec_file}, using #{exe_path}"
          exe_path
        else
          raise "no executable script found"
        end
      end

    end
  end
end
