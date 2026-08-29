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

      # Bundler settings enforced in the packed application via a generated
      # *.bundle/config*, the highest-precedence documented configuration level:
      BUNDLE_CONFIG_DEFAULTS = {
        # BUNDLE_VERSION: disable bundler's "auto-switch" to Gemfile.lock's BUNDLED WITH bundler version
        #   (bundler restarts the process to do so, which cannot work inside a servlet container or self-contained executable jar)
        'BUNDLE_VERSION' => 'system',
        # BUNDLE_FROZEN: fail fast with a descriptive error on Gemfile vs Gemfile.lock drift instead of attempting
        #   a runtime re-resolution
        'BUNDLE_FROZEN' => 'true',
        # BUNDLE_PATH__SYSTEM (path.system): pin bundler to the "system" gems - which are the packed gems, via
        #   GEM_HOME/GEM_PATH from *init.rb* - immune to a BUNDLE_PATH/BUNDLE_DEPLOYMENT leaking in from the host's
        #   environment or ~/.bundle/config
        'BUNDLE_PATH__SYSTEM' => 'true',
        # BUNDLE_AUTO_INSTALL: never install gems at boot time, even if the host's environment or global config enables it
        'BUNDLE_AUTO_INSTALL' => 'false'
      }.freeze

      def self.detect?
        File.exist?(ENV['BUNDLE_GEMFILE'] || 'Gemfile')
      end

      def self.requirements
        [ Traits::War, Traits::Jar ]
      end

      def before_configure
        config.bundler ||= true
        config.bundle_without = ['development', 'test', 'assets']
      end

      def after_configure
        add_bundler_gems if config.bundler
      end

      def add_bundler_gems; require 'bundler'
        # config.gems.clear allow to add `config.gems` on top of those bundled
        config.gem_dependencies = false # Bundler takes care of these
        config.bundler = {} if config.bundler == true

        warn_on_bundler_version_mismatch

        bundler_specs.each do |spec|
          spec = to_spec(spec)

          case spec.source
          when ::Bundler::Source::Git
            config.bundler[:git_specs] ||= []
            config.bundler[:git_specs] << spec
          when ::Bundler::Source::Path
            unless bundler_source_is_warbled_gem_itself?(spec.source)
              if spec.source.path&.relative?
                # pack the gem at its relative *[APP_ROOT]/gem/path* location - at runtime bundler resolves the path
                # source relative to the packed Gemfile.
                # Deliberately NOT also added to config.gems: bundler never materializes path gems from the gem
                # repository; doing so would cause duplication.
                config.includes += FileList[File.join(spec.source.path, '**/*')]
              else
                warn("Bundler `path' components are not fully supported.\n" +
                     "The `#{spec.full_name}' component was not bundled.\n" +
                     "Your application may fail to boot!")
              end
            end
          else
            config.gems << spec unless spec.respond_to?(:default_gem?) && spec.default_gem?
          end
        end
        config.bundler[:gemfile]  = ::Bundler.default_gemfile
        config.bundler[:gemfile_path] = apply_pathmaps(config, relative_from_pwd(::Bundler.default_gemfile), :application)
        config.bundler[:lockfile] = ::Bundler.default_lockfile
        path = ::Bundler.settings[:path]
        config.excludes += [path, "#{path}/**/*"] if path
        config.init_contents << "#{config.warbler_templates}/bundler.erb"
      end

      def update_archive(jar)
        add_bundler_files(jar) if config.bundler
      end

      # Add Bundler Gemfiles, .bundle/config and git repositories to the archive.
      def add_bundler_files(jar)
        gemfile  = relative_from_pwd(config.bundler[:gemfile])
        lockfile = relative_from_pwd(config.bundler[:lockfile])
        bundle_config = File.join('.bundle', 'config')

        jar.files[apply_pathmaps(config, gemfile, :application)] = config.bundler[:gemfile].to_s
        jar.files[apply_pathmaps(config, lockfile, :application)] = config.bundler[:lockfile].to_s if File.exist?(lockfile)
        # NOTE: in-memory content must be an IO - jar creation treats plain Strings as source file paths
        jar.files[apply_pathmaps(config, bundle_config, :application)] = StringIO.new(bundle_config_contents)

        add_bundler_git_specs(config.bundler[:git_specs], jar) if config.bundler[:git_specs]
      end

      private

      def add_bundler_git_specs(git_specs, jar)
        config.pathmaps.git = ["#{config.relative_gem_path}/bundler/gems/%p".sub(%r{^/+}, '')]

        # a git source checkout may contain multiple gems (spec.full_gem_path being a sub-directory) - bundler expects
        # the complete repository checkout under bundler/gems/<repo>-<ref>, so pack from its root (once per repository,
        # even when several specs share the checkout)
        checkout_paths = git_specs.map do |spec|
          full_gem_path = Pathname.new(spec.full_gem_path)
          filenames = full_gem_path.relative_path_from(::Bundler.install_path).each_filename.to_a
          filenames.empty? ? full_gem_path : Pathname.new(::Bundler.install_path) + filenames.first
        end.uniq

        checkout_paths.each do |checkout_path|
          FileList["#{checkout_path.to_s}/**/*"].each do |src|
            f = Pathname.new(src).relative_path_from(checkout_path).to_s
            # NOTE: for git sources the excludes match relative to the packed repository checkout root (the gem root,
            # except multi-gem repos)
            next if config.gem_excludes && config.gem_excludes.any? { |rx| f =~ rx }
            jar.files[apply_pathmaps(config, File.join(checkout_path.basename, f), :git)] = src
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

      def warn_on_bundler_version_mismatch
        lockfile = ::Bundler.default_lockfile
        return unless lockfile && File.exist?(lockfile)
        locked = ::Bundler::LockfileParser.new(File.read(lockfile)).bundler_version rescue nil
        if locked && locked.to_s != ::Bundler::VERSION
          warn("Gemfile.lock BUNDLED WITH (#{locked}) does not match the bundler running warbler (#{::Bundler::VERSION}).\n" +
               "The packed application will boot with the default bundler of the packed JRuby (jruby-jars),\n" +
               "consider re-generating Gemfile.lock with a matching bundler version.")
        end
      end

      # Contents for the packed *.bundle/config*: only warbler's deployment settings, deliberately independent of the
      # application's build-time bundler configuration.
      def bundle_config_contents
        require 'yaml'
        settings = BUNDLE_CONFIG_DEFAULTS.dup
        # frozen mode errors without a lockfile - do not force it upon applications packed without a Gemfile.lock
        settings.delete('BUNDLE_FROZEN') if config.bundler[:frozen] == false || !File.exist?(config.bundler[:lockfile].to_s)
        settings.to_yaml
      end

      def bundler_specs
        bundle_without = config.bundle_without.map { |s| s.to_sym }
        definition = ::Bundler.definition
        requested_groups = definition.groups - bundle_without
        requested_groups.empty? ? [] : definition.specs_for(requested_groups).to_a
      end

      def bundler_source_is_warbled_gem_itself?(source)
        source.path.to_s == '.'
      end
    end
  end
end
