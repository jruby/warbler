#
# Copyright (C) 2013 Christian Meier
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
require File.join(File.dirname(__FILE__), 'coordinate.rb')
require File.join(File.dirname(__FILE__), 'artifact.rb')
require 'fileutils'
module Maven
  module Tools

    class Jarfile
      include Coordinate

      def initialize(file = 'Jarfile')
        @file = file
        @lockfile = file + ".lock"
      end

      def mtime
        File.mtime(@file)
      end

      def exists?
        File.exists?(@file)
      end

      def mtime_lock
        File.mtime(@lockfile)
      end

      def exists_lock?
        File.exists?(@lockfile)
      end

      def load_lockfile
        _locked = []
        if exists_lock?
          File.read(@lockfile).each_line do |line|
            line.strip!
            if line.size > 0 && !(line =~ /^\s*#/)
              _locked << line
            end
          end
        end
        _locked
      end

      def locked
        @locked ||= load_lockfile
      end

      def locked?(coordinate)
        coord = coordinate.sub(/^([^:]+:[^:]+):.+/) { $1 }
        locked.detect { |l| l.sub(/^([^:]+:[^:]+):.+/) { $1 } == coord } != nil
      end

      class DSL
        include Coordinate

        def self.eval_file( file )
          jarfile = self.new
          jarfile.eval_file( file )
        end

        def eval_file( file )
          if File.exists?( file )
            eval( File.read( file ) )
            self
          end
        end

        def artifacts
          @artifacts ||= []
        end

        def repositories
          @repositories ||= []
        end

        def snapshot_repositories
          @snapshot_repositories ||= []
        end

        def local( path )
          artifacts << Artifact.new_local( File.expand_path( path ), :jar )
        end

        def jar( *args )
          args << '[0,)' if args.size == 1
          artifacts << Artifact.from( :jar, *args )
        end

        def pom( *args )
          args << '[0,)' if args.size == 1
          artifacts << Artifact.from( :pom, *args )
        end

        def snapshot_repository( name, url = nil )
          if url.nil?
            url = name
          end
          snapshot_repositories << { :name => name.to_s, :url => url }
        end

        def repository( name, url = nil )
          if url.nil?
            url = name
          end
          repositories << { :name => name.to_s, :url => url }
        end
        alias :source :repository

        def jruby( version = nil )
          @jruby = version if version
        end
          
      end

      def populate_unlocked( container = nil, &block )
        if File.exists?(@file)
          dsl = DSL.new
          dsl.eval_file( @file )

          if block
            block.call( dsl )
          end
          if container
            dsl.artifacts.each do |a|
              if path = a[ :system_path ]
                container.add_local_jar( path )
              elsif not locked?( a.to_s )
                container.add_artifact( a.to_s )
              end
            end
            dsl.repositories.each do |repo|
              container.add_repository( repo[ :name ] || repo[ 'name' ],
                                        repo[ :url ] || repo[ 'url' ] )
            end
            dsl.snapshot_repositories.each do |repo|
              container.add_snapshot_repository( repo[ :name ] || repo[ 'name' ],
                                                 repo[ :url ] || repo[ 'url' ] )
            end
          end
        end
      end

      def populate_locked(container)
        locked.each { |l| container.add_artifact(l) }
      end

      def generate_lockfile(dependency_coordinates)
        if dependency_coordinates.empty?
          FileUtils.rm_f(@lockfile) if exists_lock?
        else
          File.open(@lockfile, 'w') do |f|
            dependency_coordinates.each do |d|
              f.puts d.to_s unless d.to_s =~ /^ruby.bundler:/
            end
          end
        end
      end
    end

  end
end
