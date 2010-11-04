#--
# Copyright (c) 2010 Engine Yard, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

module Warbler
  module Traits
    class Bundler
      include Trait

      def self.detect?
        File.exist?("Gemfile")
      end

      def self.requires?(trait)
        trait == Traits::War
      end

      def before_configure
        config.bundler = true
        config.bundle_without = ["development", "test"]
      end

      def after_configure
        add_bundler_gems
      end

      def add_bundler_gems
        return unless config.bundler

        config.gems.clear
        config.gem_dependencies = false # Bundler takes care of these

        require 'bundler'
        gemfile = Pathname.new("Gemfile").expand_path
        root = gemfile.dirname
        lockfile = root.join('Gemfile.lock')
        definition = ::Bundler::Definition.build(gemfile, lockfile, nil)
        groups = definition.groups - config.bundle_without.map {|g| g.to_sym}
        definition.specs_for(groups).each {|spec| config.gems << spec }
        config.init_contents << StringIO.new("ENV['BUNDLE_WITHOUT'] = '#{config.bundle_without.join(':')}'\n")
      end
    end
  end
end
