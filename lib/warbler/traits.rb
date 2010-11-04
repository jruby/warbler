module Warbler
  # Traits are project configuration characteristics that correspond
  # to the framework or project layout. Each trait corresponds to a
  # class in Warbler::Traits that contains baked-in knowledge about
  # the kind of project and how it should be packed into the jar or
  # war file.
  module Traits
    attr_accessor :traits

    def initialize
      @traits = auto_detect_traits
    end

    def auto_detect_traits
      [Traits::War]
    end

    def before_configure
      trait_objects.each {|t| t.before_configure }
    end

    def after_configure
      trait_objects.each {|t| t.after_configure }
    end

    def trait_objects
      @trait_objects ||= @traits.map {|klass| klass.new(self) }
    end

    def dump_traits
      @trait_objects = nil
      @traits.collect! {|t| t.name }
    end
  end

  # Each trait class includes this module to receive shared functionality.
  module Trait
    attr_reader :config
    def initialize(config)
      @config = config
    end

    def before_configure
    end

    def after_configure
    end
  end
end

require 'warbler/traits/war'
require 'warbler/traits/rails'
require 'warbler/traits/merb'
require 'warbler/traits/rack'
require 'warbler/traits/bundler'
