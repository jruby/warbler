require 'maven/ruby/maven'
require 'maven/tools/visitor'
module JBundler
  # mimic the new maven class - prepare for upgrade
  class MavenNG

    def initialize( project, temp_pom = nil )
      f = File.expand_path( File.join( temp_pom || '.pom.xml' ) )
      v = ::Maven::Tools::Visitor.new( File.open( f, 'w' ) )
      # parse block and write out pom4rake.xml file
      v.accept_project( project )
      # tell maven to use the generated file
      @rmvn = ::Maven::Ruby::Maven.new
      @rmvn.options[ '-f' ] = f
      @rmvn.options[ '-B' ] = nil
    end

    def exec( *args )
      @rmvn.exec_in( File.expand_path( '.' ), *args )
    end

    def method_missing( method, *args )
      @rmvn.exec( [ method ] + args )
    end
  end
end

