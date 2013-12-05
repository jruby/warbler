require 'maven/tools/jarfile'
require 'maven/tools/dsl'
require 'maven/ruby/maven'
require 'fileutils'
require 'jbundler/executable_pom'
module JBundler
  class Executable

    class Filter
      
      def initialize(a)
        @a = a
      end
      def method_missing(m, *args, &b)
        args[ 0 ].sub!(/^.* - /, '' )
        args[ 0 ] = 'asd'
        @a.send(m,*args, &b)
      end
    end

    BOOTSTRAP = 'jar-bootstrap.rb'

    include Maven::Tools::DSL

    def initialize( bootstrap, config, compile, verbose, *groups )
      raise "file not found: #{bootstrap}" unless File.exists?( bootstrap )
      @pom = ExecutablePom.new( bootstrap, config, compile, verbose, *groups )
    end

    def packit
      m = Maven::Ruby::Maven.new( @pom.project, '.executable.pom.xml' )
      m.verbose = @verbose
      m.package

      FileUtils.rm_f( 'dependency-reduced-pom.xml' )
      puts
      puts 'now you can execute your jar like this'
      puts
      puts "\tjava -jar #{@pom.work_dir}/#{@pom.project.artifact_id}.jar"
      puts
    end
  end
end
