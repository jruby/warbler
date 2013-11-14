require 'maven/tools/coordinate'

module Maven
  module Tools
    class GemspecDependencies

      def initialize( gemspec )
        if gemspec.is_a? Gem::Specification
          @spec = gemspec
        else
          @spec = Gem::Specification.load( gemspec )
        end
        _setup
      end

      def java_runtime
        _deps( :java_runtime )
      end

      def runtime
        _deps( :runtime )
      end

      def development
        _deps( :development )
      end

      private

      include Coordinate

      def _deps( type )
        @deps ||= {}
        @deps[ type ] ||= []
      end

      def _setup
        @spec.dependencies.each do |dep|
          versions = dep.requirement.requirements.collect do |req|
            # use this construct to get the same result in 1.8.x and 1.9.x
            req.collect{ |i| i.to_s }.join
          end
          _deps( dep.type ) << "rubygems:#{dep.name}:#{to_version( *versions )}"
        end
        @spec.requirements.each do |req|
          coord = to_split_coordinate( req )
          _deps( :java_runtime ) << coord if coord
        end
      end
    end
  end
end
