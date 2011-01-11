#--
# Copyright (c) 2010-2011 Engine Yard, Inc.
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

      def self.detect?
        !War.detect?
      end

      def before_configure
        config.pathmaps      = default_pathmaps
        config.java_libs     = default_jar_files
        config.manifest_file = 'MANIFEST.MF' if File.exist?('MANIFEST.MF')
      end

      def after_configure
        config.init_contents << StringIO.new("require 'rubygems'\n")
      end

      def update_archive(jar)
        jar.files['META-INF/MANIFEST.MF'] = StringIO.new(Warbler::Jar::DEFAULT_MANIFEST.chomp + "Main-Class: JarMain\n") unless config.manifest_file
        jar.files['JarMain.class'] = jar.entry_in_jar("#{WARBLER_HOME}/lib/warbler_jar.jar", "JarMain.class")
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
        require 'jruby-jars'
        FileList[JRubyJars.core_jar_path, JRubyJars.stdlib_jar_path]
      end
    end
  end
end
