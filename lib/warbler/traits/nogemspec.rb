#--
# Copyright (c) 2010 Engine Yard, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'stringio'

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
          require_path = config.pathmaps.application.inject("lib") {|pm,x| pm.pathmap(x)}
          config.init_contents << StringIO.new("$LOAD_PATH.unshift '#{require_path}'")
        end
      end

      def update_archive(jar)
        bin_path = jar.apply_pathmaps(config, default_executable, :application)
        jar.files['META-INF/main.rb'] = StringIO.new("load File.expand_path '../../#{bin_path}', __FILE__")
      end

      def default_executable
        exe = Dir['bin/*'].first
        raise "No executable script found" unless exe
        exe
      end
    end
  end
end
