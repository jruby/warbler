#--
# Copyright (c) 2010-2011 Engine Yard, Inc.
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
        (Dir['**/*'] - config.compiled_ruby_files).each do |f|
          jar.files[jar.apply_pathmaps(config, f, :application)] = f
        end
        config.compiled_ruby_files.each do |f|
          f = f.sub(/\.rb$/, '.class')
          next unless File.exist?(f)
          jar.files[jar.apply_pathmaps(config, f, :application)] = f
        end
        bin_path = jar.apply_pathmaps(config, default_executable, :application)
        add_main_rb(jar, bin_path)
      end

      def default_executable
        if !@spec.executables.empty?
          "bin/#{@spec.executables.first}"
        else
          exe = Dir['bin/*'].first
          raise "No executable script found" unless exe
          warn "No default executable found in #{@spec_file}, using #{exe}"
          exe
        end
      end
    end
  end
end
