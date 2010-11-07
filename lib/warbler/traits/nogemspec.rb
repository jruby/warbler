#--
# Copyright (c) 2010 Engine Yard, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

module Warbler
  module Traits
    class NoGemspec
      include Trait

      def self.detect?
        Jar.detect? && !Gemspec.detect?
      end

      def before_configure
        config.dirs = ['.']
      end

      def after_configure
        if File.directory?("lib")
          add_init_load_path(config.pathmaps.application.inject("lib") {|pm,x| pm.pathmap(x)})
        end
      end

      def update_archive(jar)
        add_main_rb(jar, jar.apply_pathmaps(config, default_executable, :application))
      end

      def default_executable
        exe = Dir['bin/*'].first
        raise "No executable script found" unless exe
        exe
      end
    end
  end
end
