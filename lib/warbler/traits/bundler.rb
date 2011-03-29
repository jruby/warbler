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
        File.exist?(ENV['BUNDLE_GEMFILE'] || "Gemfile")
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
        config.bundler = {}

        require 'bundler'
        gemfile  = config.bundler[:gemfile]  = ::Bundler.default_gemfile
        lockfile = config.bundler[:lockfile] = ::Bundler.default_lockfile
        definition = ::Bundler::Definition.build(gemfile, lockfile, nil)
        groups = definition.groups - config.bundle_without.map {|g| g.to_sym}
        definition.specs_for(groups).each {|spec| config.gems << spec }
        config.init_contents << "#{config.warbler_templates}/bundler.erb"
      end

      def update_archive(jar)
        add_bundler_files(jar) if config.bundler
      end

      # Add Bundler Gemfiles to the archive.
      def add_bundler_files(jar)
        pwd = Pathname.new(Dir.pwd)
        gemfile  = config.bundler[:gemfile].relative_path_from(pwd).to_s
        lockfile = config.bundler[:lockfile].relative_path_from(pwd).to_s
        jar.files[jar.apply_pathmaps(config, gemfile, :application)] = config.bundler[:gemfile].to_s
        if File.exist?(lockfile)
          jar.files[jar.apply_pathmaps(config, lockfile, :application)] = config.bundler[:lockfile].to_s
        end
      end
    end
  end
end
