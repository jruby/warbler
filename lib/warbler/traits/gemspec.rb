#--
# Copyright (c) 2010 Engine Yard, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'stringio'

module Warbler
  module Traits
    class Gemspec
      include Trait

      def self.detect?
        !Dir['*.gemspec'].empty?
      end

      def before_configure
        @spec_file = Dir['*.gemspec'].first
        @spec = eval(File.read(@spec_file))
        @spec.runtime_dependencies.each {|g| config.gems << g }
        config.dirs = []
      end

      def after_configure
        code = @spec.require_paths.map do |p|
          require_path = config.pathmaps.application.inject(p) {|pm,x| pm.pathmap(x)}
          "$LOAD_PATH.unshift '#{require_path}'"
        end.join("\n")
        config.init_contents << StringIO.new(code)
      end

      def update_archive(jar)
        @spec.files.each do |f|
          jar.files[jar.apply_pathmaps(config, f, :application)] = f
        end
        bin_path = jar.apply_pathmaps(config, default_executable, :application)

        jar.files['META-INF/main.rb'] = StringIO.new("load File.expand_path '../../#{bin_path}', __FILE__")
      end

      def default_executable
        if @spec.default_executable
          "bin/#{@spec.default_executable}"
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
