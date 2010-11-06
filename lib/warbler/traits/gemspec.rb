#--
# Copyright (c) 2010 Engine Yard, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

module Warbler
  module Traits
    class Gemspec
      include Trait

      def self.detect?
        !Dir['*.gemspec'].empty?
      end

      def before_configure
        @spec = eval(File.read(Dir['*.gemspec'].first))
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
      end
    end
  end
end
