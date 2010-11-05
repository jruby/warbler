#--
# Copyright (c) 2010 Engine Yard, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'ostruct'

module Warbler
  module Traits
    class Jar
      include Trait

      DEFAULT_GEM_PATH = '/META-INF/gems'

      def self.detect?
        !War.detect?
      end

      def before_configure
        config.gem_path  = DEFAULT_GEM_PATH
        config.pathmaps  = default_pathmaps
        config.java_libs = default_jar_files
      end

      def after_configure
        update_gem_path(DEFAULT_GEM_PATH)
      end

      def default_pathmaps
        p = OpenStruct.new
        p.java_libs    = ["META-INF/lib/%f"]
        p.java_classes = ["%p"]
        p.application  = ["#{config.jar_name}/%p"]
        p.gemspecs     = ["#{config.relative_gem_path}/specifications/%f"]
        p.gems         = ["#{config.relative_gem_path}/gems/%p"]
        p
      end

      def default_jar_files
        require 'jruby-jars'
        FileList[JRubyJars.core_jar_path, JRubyJars.stdlib_jar_path]
      end
    end
  end
end
