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

      def self.detect?
        !Dir['*.gemspec'].empty?
      end

      def before_configure
        @spec_file = Dir['*.gemspec'].first
        require 'yaml'
        @spec = load_spec(@spec_file)
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
          jar.files[apply_pathmaps(config, f, :application)] = f
        end
        config.compiled_ruby_files.each do |f|
          f = f.sub(/\.rb$/, '.class')
          next unless File.exist?(f)
          jar.files[apply_pathmaps(config, f, :application)] = f
        end
        bin_path = apply_pathmaps(config, default_executable, :application)
        add_main_rb(jar, bin_path)
      end

      def default_executable
        if !@spec.executables.empty?
          "bin/#{@spec.executables.first}"
        else
          exe = Dir['bin/*'].sort.first
          raise "No executable script found" unless exe
          warn "No default executable found in #{@spec_file}, using #{exe}"
          exe
        end
      end

      protected

      def load_spec(path)
        Gem::Specification.from_yaml File.read(path)
      rescue Gem::Exception, *parse_error($!)
        Gem::Specification.load(path)
      end

      PARSE_ERRORS = %w[Psych::SyntaxError Syck::ParseError]
      # Allows to intercept YAML exceptions even if one of both official
      # modules is not loaded.
      #
      # Usage:
      #     begin
      #       YAML.parse(something)
      #     rescue parse_error($!) => ex
      #       ...
      #     end
      def parse_error(ex)
        if PARSE_ERRORS.include? ex.class.name
          [ex.class]
        else
          []
        end
      end
    end
  end
end
