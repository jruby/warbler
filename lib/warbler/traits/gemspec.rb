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

      def before_configure
        @spec_file = Dir['*.gemspec'].first
        require 'yaml'
        @spec = File.open(@spec_file) {|f| Gem::Specification.from_yaml(f) } rescue Gem::Specification.load(@spec_file)
        @spec.runtime_dependencies.each {|g| config.gems << g }
        config.dirs = []
        config.compiled_ruby_files = @spec.files.select {|f| f =~ /\.rb$/}
      end

      def after_configure
        @spec.require_paths.each do |p|
          add_init_load_path(config.pathmaps.application.inject(p) {|pm,x| pm.pathmap(x)})
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
        if !@spec.executables.empty?
          bundler_version =
            Gem.loaded_specs.include?("bundler") ?
              Gem.loaded_specs["bundler"].version :
              Gem::Version.create("0.0.0")
          if (bundler_version <=> Gem::Version.create("1.8.0")) < 0
            "bin/#{@spec.executables.first}"
          else
            exe_script = @spec.executables.first
            if File.exists?("exe/#{exe_script}")
              "exe/#{exe_script}"
            elsif File.exists?("bin/#{exe_script}")
              "bin/#{exe_script}"
            else
              raise "No `#{exe_script}` executable script found"
            end
          end
        elsif exe = Dir['bin/*'].sort.first
          warn "No default executable found in #{@spec_file}, using bin/#{exe}"
          exe
        elsif exe = Dir['exe/*'].sort.first
          warn "No default executable found in #{@spec_file}, using exe/#{exe}"
          exe
        else
          raise "No executable script found" unless exe
        end
      end
    end
  end
end
