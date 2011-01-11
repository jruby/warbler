#--
# Copyright (c) 2010-2011 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

module Warbler
  module Traits
    # The Bundler trait uses Bundler to determine gem dependencies to
    # be added to the project.
    class Bundler
      include Trait

      def self.detect?
        File.exist?("Gemfile")
      end

      def self.requires?(trait)
        trait == Traits::War || trait == Traits::Jar
      end

      def before_configure
        config.bundler = true
        config.bundle_without = ["development", "test"]
      end

      def after_configure
        add_bundler_gems if config.bundler
      end

      def add_bundler_gems
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

      def update_archive(jar)
        add_bundler_files(jar) if config.bundler
      end

      # Add Bundler Gemfiles to the archive.
      def add_bundler_files(jar)
        jar.files[jar.apply_pathmaps(config, 'Gemfile', :application)] = 'Gemfile'
        if File.exist?('Gemfile.lock')
          jar.files[jar.apply_pathmaps(config, 'Gemfile.lock', :application)] = 'Gemfile.lock'
        end
      end
    end
  end
end
