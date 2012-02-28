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
	require 'bundler'
        config.gems.clear
        config.gem_dependencies = false # Bundler takes care of these
        config.bundler = {}

        bundler_specs.each do |spec|
          # Bundler HAX -- fixup bad #loaded_from attribute in fake
          # bundler gemspec from bundler/source.rb
          if spec.name == "bundler"
            full_gem_path = Pathname.new(spec.full_gem_path)
            tries = 2
            (full_gem_path = full_gem_path.dirname; tries -= 1) while tries > 0 && !full_gem_path.join('bundler.gemspec').exist?
            spec.loaded_from = full_gem_path.to_s
          end

          case spec.source
          when ::Bundler::Source::Git
            config.bundler[:git_specs] ||= []
            config.bundler[:git_specs] << spec
          when ::Bundler::Source::Path
            $stderr.puts("warning: Bundler `path' components are not currently supported.",
                         "The `#{spec.full_name}' component was not bundled.",
                         "Your application may fail to boot!")
          else
            config.gems << spec
          end
        end
        config.bundler[:gemfile]  = ::Bundler.default_gemfile
        config.bundler[:lockfile] = ::Bundler.default_lockfile
        config.bundler[:frozen] = ::Bundler.settings[:frozen]
        path = ::Bundler.settings[:path]
        config.excludes += [path, "#{path}/**/*"] if path
        config.init_contents << "#{config.warbler_templates}/bundler.erb"
      end

      def update_archive(jar)
        add_bundler_files(jar) if config.bundler
      end

      # Add Bundler Gemfiles and git repositories to the archive.
      def add_bundler_files(jar)
        pwd = Pathname.new(Dir.pwd)
        gemfile  = config.bundler[:gemfile].relative_path_from(pwd).to_s
        lockfile = config.bundler[:lockfile].relative_path_from(pwd).to_s
        jar.files[jar.apply_pathmaps(config, gemfile, :application)] = config.bundler[:gemfile].to_s
        if File.exist?(lockfile)
          jar.files[jar.apply_pathmaps(config, lockfile, :application)] = config.bundler[:lockfile].to_s
        end
        if config.bundler[:git_specs]
          pathmap = "#{config.relative_gem_path}/bundler/gems/%p"
          pathmap.sub!(%r{^/+}, '')
          config.pathmaps.git = [pathmap]
          config.bundler[:git_specs].each do |spec|
            full_gem_path = Pathname.new(spec.full_gem_path)
 
            gem_relative_path = full_gem_path.relative_path_from(::Bundler.install_path) 
            filenames = []
            gem_relative_path.each_filename { |f| filenames << f }
            
            if filenames.empty?
              # full_gem_path has only one gem
              FileList["#{full_gem_path.to_s}/**/*"].each do |src|
                f = Pathname.new(src).relative_path_from(full_gem_path).to_s
                next if config.gem_excludes && config.gem_excludes.any? {|rx| f =~ rx }
                jar.files[jar.apply_pathmaps(config, File.join(full_gem_path.basename, f), :git)] = src
              end
            else
              gem_base_path = Pathname.new(::Bundler.install_path) + filenames.first
              FileList["#{gem_base_path.to_s}/**/*"].each do |src|
                f = Pathname.new(src).relative_path_from(gem_base_path).to_s
                jar.files[jar.apply_pathmaps(config, File.join(gem_base_path.basename, f), :git)] = src
              end
            end
          end
        end
      end

      private

      def bundler_specs
	original_without = ::Bundler.settings.without
	::Bundler.settings.without = config.bundle_without

	::Bundler::Definition.build(::Bundler.default_gemfile, ::Bundler.default_lockfile, nil).requested_specs
      ensure
	# need to set the settings back, otherwise they get persisted in .bundle/config
	::Bundler.settings[:without] = original_without.join(':')
      end
    end
  end
end
