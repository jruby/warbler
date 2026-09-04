#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'stringio'
require 'ostruct'

module Warbler
  module Traits
    # The Jar trait sets up the archive layout for an executable jar
    # project, and adds the JRuby jar files and a JarMain class to the
    # archive.
    class Jar
      include Trait

      MAIN_PATH_TO_CLASS = 'warbler/JarMain.class'.freeze

      def self.detect?
        !detect_any_conflicts?
      end

      def self.conflicts
        [ Traits::War ]
      end

      def before_configure
        config.gem_path      = '/'
        config.pathmaps      = default_pathmaps
        config.java_libs     = default_jar_files
        config.manifest_file = 'MANIFEST.MF' if File.exist?('MANIFEST.MF')
        config.init_contents << "#{config.warbler_templates}/jar.erb"
      end

      def update_archive(jar)
        unless config.manifest_file
          jar.files[Warbler::Jar::MANIFEST_PATH] = StringIO.new(Warbler::Jar.manifest_with_main(MAIN_PATH_TO_CLASS))
        end
        jar.files[MAIN_PATH_TO_CLASS] = jar.entry_in_jar(WARBLER_JAR, MAIN_PATH_TO_CLASS)
      end

      def default_pathmaps
        p = OpenStruct.new
        p.java_libs    = ["META-INF/lib/%f"]
        p.java_classes = ["%p"]
        p.application  = ["#{config.jar_name}/%p"]
        p.gemspecs     = ["specifications/%f"]
        p.gems         = ["gems/%p"]
        p
      end

      def default_jar_files
        jruby_jars
      end
    end
  end
end
