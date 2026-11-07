# encoding: UTF-8

module Warbler
  module Traits
    class CompiledGems

      include Trait
      include RakeHelper

      def self.detect?
        # Don't have access to @config here, so always return true and check
        # @config.compile_gems later.
        true
      end

      def self.requirements
        [Traits::Jar, Traits::War]
      end

      def after_configure
        if @config.compile_gems
          define_tasks
        end
      end

      def update_archive(jar)
        if @config.compile_gems
          copy_excluded_files(jar)
          fix_double_web_inf_paths(jar)
        end
      end

      private

      # When building .war files, warbler mistakenly adds WEB-INF/ twice to
      # the beginning of each individual .class file, which causes them to not
      # get copied over into the package.
      def fix_double_web_inf_paths(jar)
        new_files = jar.files.each_with_object({}) do |(inside_jar, file_system_location), ret|
          new_inside_jar = inside_jar.gsub(/\AWEB-INF\/WEB-INF/, 'WEB-INF')
          ret[new_inside_jar] = file_system_location
        end

        jar.instance_variable_set(:'@files', new_files)
      end

      # Hack to copy over files excluded from compilation.
      #
      # Warbler doesn't provide a way to exclude files only from compilation,
      # then copy those files over to the jar/war. This method executes before
      # files get copied and updates the jar's file map.
      def copy_excluded_files(jar)
        @config.gems.specs(@config.gem_dependencies).each do |spec|
          full_gem_path = Pathname.new(spec.full_gem_path)
          FileList["#{full_gem_path.to_s}/**/*"].each do |src|
            f = Pathname.new(src).relative_path_from(full_gem_path).to_s
            if @config.gem_excludes.any? { |rx| f =~ rx }
              jar.files[jar.apply_pathmaps(@config, File.join(spec.full_name, f), :gems)] = src
            end
          end
        end
      end

      # Hack to compile gems that come from git repositories.
      #
      # For some reason, warbler keeps git-based gems in a different hash,
      # separate from all the other gems. This means they miss out on
      # getting compiled, among other things.
      def fix_gems
        @config.bundler[:git_specs].each do |git_spec|
          @config.gems << git_spec
        end

        @config.bundler.delete(:git_specs)
      end

      def define_tasks
        namespace :jar do
          task :before_compiled do
            fix_gems
          end
        end

        namespace :war do
          task :before_compiled do
            fix_gems
          end
        end

        task 'jar:compiled' => 'jar:before_compiled'
        task 'war:compiled' => 'war:before_compiled'
      end

    end
  end
end
