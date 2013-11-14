#
# Copyright (C) 2013 Kristian Meier
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
# the Software, and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
# FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
require 'yaml'
require 'jbundler/config'
require 'maven'

module JBundler

  class AetherRuby

    def self.setup_classloader
      require 'java'

      Dir.glob( File.join( Maven.lib, '*.jar' ) ).each do |path|
        require path
      end
      begin
        require 'jbundler.jar'
      rescue LoadError
        # allow the classes already be added to the classloader
        begin
          java_import 'jbundler.Aether'
        rescue NameError
          # assume this happens only when working on the git clone
          raise "jbundler.jar is missing - maybe you need to build it first ? use\n$ rmvn prepare-package -Dmaven.test.skip\n"
        end
      end
      java_import 'jbundler.Aether'
    end

    def initialize( config = Config.new )
      unless defined? Aether
        self.class.setup_classloader
      end
      @aether = Aether.new( config.verbose )
      @aether.add_proxy( config.proxy ) if config.proxy
      @aether.add_mirror( config.mirror ) if config.mirror
      @aether.offline = config.offline
      @aether.user_settings = config.settings if config.settings
      @aether.local_repository = java.io.File.new(config.local_repository) if config.local_repository
    rescue NativeException => e
      e.cause.print_stack_trace
      raise e
    end

    def local_jars
      @local_jars ||= []
    end

    def add_local_jar( path )
       local_jars << File.expand_path( path )
    end

    def add_artifact(coordinate, extension = nil)
      if extension
        coord = coordinate.split(/:/)
        coord.insert(2, extension)
        @aether.add_artifact(coord.join(":"))
      else
        @aether.add_artifact(coordinate)
      end
    end

    def add_repository(name, url)
      @aether.add_repository(name, url)
    end

    def add_snapshot_repository(name, url)
      @aether.add_snapshot_repository(name, url)
    end

    def resolve
      @aether.resolve unless artifacts.empty?
    rescue NativeException => e
      e.cause.print_stack_trace
      raise e
    end

    def classpath
      if artifacts.empty? and local_jars.empty?
        ''
      else
        path = [ @aether.classpath ] 
        path = path + @local_jars if @local_jars
        path.join( File::PATH_SEPARATOR )
      end
    end

    def classpath_array
      classpath.split(/#{File::PATH_SEPARATOR}/)
    end

    def repositories
      @aether.repositories
    end

    def artifacts
      @aether.artifacts
    end

    def resolved_coordinates
      if @aether.artifacts.empty?
        []
      else
        @aether.resolved_coordinates
      end
    end

    def install(coordinate, file)
      @aether.install(coordinate, file)
    rescue NativeException => e
      e.cause.print_stack_trace
      raise e
    end

  end
end
