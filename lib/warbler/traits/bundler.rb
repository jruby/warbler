#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
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
      include PathmapHelper
      include BundlerHelper

      def self.detect?
        File.exist?(ENV['BUNDLE_GEMFILE'] || "Gemfile")
      end

      def self.requirements
        [ Traits::War, Traits::Jar ]
      end

      def before_configure
        config.bundler = true
        config.bundle_without = ["development", "test", "assets"]
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
          spec = to_spec(spec)
          # Bundler HAX -- fixup bad #loaded_from attribute in fake
          # bundler gemspec from bundler/source.rb
          if spec.name == 'bundler'
            full_gem_path = Pathname.new(spec.full_gem_path)
            while ! full_gem_path.join('bundler.gemspec').exist?
              full_gem_path = full_gem_path.dirname
              # if at top of the path, meaning we cannot find bundler.gemspec, abort.
              if full_gem_path.to_s =~ /^[\.\/]$/
                $stderr.puts("warning: Unable to detect bundler spec under '#{spec.full_gem_path}'' and is sub-dirs")
                exit
              end
            end

            spec.loaded_from = full_gem_path.join('bundler.gemspec').to_s
            # RubyGems 1.8.x: @full_gem_path is cached, so we have to set it
            def spec.full_gem_path=(p); @full_gem_path = p; end
            spec.full_gem_path = full_gem_path.to_s
          end

          case spec.source
          when ::Bundler::Source::Git
            config.bundler[:git_specs] ||= []
            config.bundler[:git_specs] << spec
          when ::Bundler::Source::Path
            unless bundler_source_is_warbled_gem_itself?(spec.source)
              $stderr.puts("warning: Bundler `path' components are not currently supported.",
                           "The `#{spec.full_name}' component was not bundled.",
                           "Your application may fail to boot!")
            end
          else
            config.gems << spec
          end
        end
        config.bundler[:gemfile]  = ::Bundler.default_gemfile
        config.bundler[:gemfile_path] = apply_pathmaps(config, relative_from_pwd(::Bundler.default_gemfile), :application)
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
        gemfile  = relative_from_pwd(config.bundler[:gemfile])
        lockfile = relative_from_pwd(config.bundler[:lockfile])
        jar.files[apply_pathmaps(config, gemfile, :application)] = config.bundler[:gemfile].to_s
        if File.exist?(lockfile)
          jar.files[apply_pathmaps(config, lockfile, :application)] = config.bundler[:lockfile].to_s
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

            exclude_gems = true
            unless filenames.empty?
              full_gem_path = Pathname.new(::Bundler.install_path) + filenames.first
              exclude_gems = false
            end

            if spec.groups.include?(:warbler_excluded)
              pattern = "#{full_gem_path.to_s}/**/#{spec.name}.gemspec" # #42: gemspec only to avert Bundler error
            else
              pattern = "#{full_gem_path.to_s}/**/*"
            end

            FileList[pattern].each do |src|
              f = Pathname.new(src).relative_path_from(full_gem_path).to_s
              next if exclude_gems && config.gem_excludes && config.gem_excludes.any? {|rx| f =~ rx }
              jar.files[apply_pathmaps(config, File.join(full_gem_path.basename, f), :git)] = src
            end
          end
        end
      end

      def relative_from_pwd(path)
        if path.relative?
          path
        else
          path.relative_path_from(Pathname.new(Dir.pwd)).to_s
        end
      end

      private

      def bundler_specs
        bundle_without = config.bundle_without.map { |s| s.to_sym }
        definition = ::Bundler.definition
        all = definition.specs.to_a
        requested = definition.specs_for(definition.groups - bundle_without).to_a
        excluded_git_specs = (all - requested).select { |spec| ::Bundler::Source::Git === spec.source }
        excluded_git_specs.each { |spec| spec.groups << :warbler_excluded }
        requested + excluded_git_specs
      end

      def bundler_source_is_warbled_gem_itself?(source)
        source.path.to_s == '.'
      end
    end
  end
end
