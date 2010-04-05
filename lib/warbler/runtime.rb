module Warbler
  # Extension module for a Bundler::Runtime instance, to add methods
  # to create a Bundler environment file specific to war packaging.
  module Runtime
    WAR_ENV = ".bundle/war-environment.rb"

    attr_writer :gem_path
    def gem_path
      @gem_path || Config::DEFAULT_GEM_PATH
    end

    class Spec
      def initialize(spec, gem_path)
        location = spec[:loaded_from][%r{(.*)/specifications}, 1]
        spec = spec.dup
        spec[:loaded_from] = spec[:loaded_from].sub(location, gem_path)
        spec[:load_paths] = spec[:load_paths].map {|p| p.sub(location, gem_path)}
        @spec = spec
      end

      def inspect
        str = @spec.inspect
        str.gsub(%r'"/WEB-INF(/[^"]*)"', 'File.expand_path("../..\1", __FILE__)')
      end
    end

    def rb_lock_file
      root.join(WAR_ENV)
    end

    def specs_for_lock_file
      super.map {|s| Spec.new(s, gem_path)}
    end

    def write_war_environment
      write_rb_lock
    end

    def war_specs
      respond_to?(:requested_specs) ? requested_specs : specs_for
    end
  end
end
