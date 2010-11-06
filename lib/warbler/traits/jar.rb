#--
# Copyright (c) 2010 Engine Yard, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'stringio'
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
        config.gem_path      = DEFAULT_GEM_PATH
        config.pathmaps      = default_pathmaps
        config.java_libs     = default_jar_files
        config.manifest_file = 'MANIFEST.MF' if File.exist?('MANIFEST.MF')
      end

      def after_configure
        update_gem_path(DEFAULT_GEM_PATH)
        config.init_contents << StringIO.new(gem_path_code)
      end

      def update_archive(jar)
        jar.files['META-INF/MANIFEST.MF'] = StringIO.new(Warbler::Jar::DEFAULT_MANIFEST.chomp + "Main-Class: JarMain\n") unless config.manifest_file
        jar.files['JarMain.class'] = Zip::ZipFile.open("#{WARBLER_HOME}/lib/warbler_jar.jar") do |zf|
          zf.get_input_stream('JarMain.class') {|io| StringIO.new(io.read) }
        end
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

      def gem_path_code
        code = <<-CODE
if ENV['GEM_PATH']
  ENV['GEM_PATH'] = '#{config.relative_gem_path}' + File::PATH_SEPARATOR + ENV['GEM_PATH']
else
  ENV['GEM_PATH'] = '#{config.relative_gem_path}'
end
require 'rubygems'
CODE
      end
    end
  end
end
