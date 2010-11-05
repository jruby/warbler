#--
# Copyright (c) 2010 Engine Yard, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

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
      Traits.constants.map {|t| Traits.const_get(t)}.select {|tc| tc.detect? }.sort
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

    def update_archive(jar)
      trait_objects.each {|t| t.update_archive(jar) }
    end

    def dump_traits
      @trait_objects = nil
      @traits.collect! {|t| t.name }
    end
  end

  # Each trait class includes this module to receive shared functionality.
  module Trait
    module ClassMethods
      def <=>(o)
        requires?(o) ? 1 : (o.requires?(self) ? -1 : 0)
      end

      def requires?(t)
        false
      end
    end

    def self.included(base)
      base.extend ClassMethods
    end

    attr_reader :config
    def initialize(config)
      @config = config
    end

    def before_configure
    end

    def after_configure
    end

    def update_archive(jar)
    end

    def update_gem_path(default_gem_path)
      if config.gem_path != default_gem_path
        config.gem_path = "/#{config.gem_path}" unless config.gem_path =~ %r{^/}
        sub_gem_path = config.gem_path[1..-1]
        config.pathmaps.gemspecs.each {|p| p.sub!(default_gem_path[1..-1], sub_gem_path)}
        config.pathmaps.gems.each {|p| p.sub!(default_gem_path[1..-1], sub_gem_path)}
        config.webxml["gem"]["path"] = config.gem_path if config.webxml
      end
    end
  end
end

require 'warbler/traits/jar'
require 'warbler/traits/war'
require 'warbler/traits/rails'
require 'warbler/traits/merb'
require 'warbler/traits/rack'
require 'warbler/traits/bundler'
