require 'maven/tools/jarfile'
require 'maven/tools/dsl'
require 'maven/tools/model'
require 'maven/ruby/maven'
require 'fileutils'
module JBundler
  class Tree

    include Maven::Tools::DSL

    def initialize( config )
      @config = config
    end

    def show_it( debug = false )
      require 'jbundler'
      jfile = ::Maven::Tools::Jarfile.new( @config.jarfile )
      project = maven do
        basedir( File.dirname( @config.jarfile ) )

        gemfile( @config.gemfile ) if File.exists? @config.gemfile

        jarfile :skip_locked => true

        build.directory = @config.work_dir if @config.work_dir != 'target'
        
        properties( 'project.build.sourceEncoding' => 'utf-8' )
      end

      output = java.io.ByteArrayOutputStream.new
      out = java.io.PrintStream.new( output )
      old = java.lang.System.err
      java.lang.System.err = out

      m = Maven::Ruby::Maven.new( project, '.tree.pom.xml' )
      m.exec( 'org.apache.maven.plugins:maven-dependency-plugin:2.8:tree' )
      result = output.to_string( 'utf-8' ).split( "\n" )
      result = result.each do |line|
        line.gsub!( /\[[^ ]+\] /, '' )
      end
      unless debug
        result = result.select do |line|
          line =~ /^[INFO].*/
        end
      end
      result = result.each do |line|
        line.gsub!( /^.* - /, '' )
      end
      $stdout.puts result.join( "\n" )#.gsub( /^.* - /, '' )#.gsub( /\n\n\n/, "\n" )
    ensure
      java.lang.System.err = old
    end
  end
end
