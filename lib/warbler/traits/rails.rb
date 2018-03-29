#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

module Warbler
  module Traits
    # The Rails trait invokes the Rake environment task and sets up Rails for a war-based project.
    class Rails
      include Trait

      def self.detect?
        File.exist?('config/environment.rb')
      end

      def self.requirements
        [ Traits::War ]
      end

      def before_configure
        config.jar_name = default_app_name
        config.webxml.rails.env = ENV['RAILS_ENV'] || 'production'
        config.pathmaps.public_html << "%{packs/(manifest.*),WEB-INF/public/packs/\\1}p"

        return unless Warbler.framework_detection
        return false unless task = Warbler.project_application.lookup('environment')

        task.invoke rescue nil
        return false unless defined?(::Rails)

        config.dirs << 'tmp' if File.directory?('tmp')
        config.webxml.booter = :rails
        unless (defined?(::Rails.vendor_rails?) && ::Rails.vendor_rails?) || File.directory?('vendor/rails')
          config.gems['rails'] = ::Rails::VERSION::STRING unless Bundler.detect?
        end
        if defined?(::Rails.configuration.gems)
          ::Rails.configuration.gems.each do |g|
            config.gems << Gem::Dependency.new(g.name, g.requirement) if Dir["vendor/gems/#{g.name}*"].empty?
          end
        end
        config.script_files << "#{config.warbler_scripts}/rails.rb"
      end

      def after_configure
        config.init_contents << "#{config.warbler_templates}/rails.erb"

        if config.webxml.jruby.min.runtimes.is_a?(OpenStruct) &&
           config.webxml.jruby.max.runtimes.is_a?(OpenStruct) # not set
           if rails_major_version(0) >= 4 || threadsafe_enabled?
             config.webxml.jruby.min.runtimes = 1
             config.webxml.jruby.max.runtimes = 1
           end
        end

        config.includes += FileList["public/assets/.sprockets-manifest-*.json"].existing
        config.includes += FileList["public/assets/manifest-*.json"].existing
        config.includes += FileList["public/assets/manifest.yml"].existing
      end

      def default_app_name
        File.basename(File.expand_path(defined?(::Rails.root) ? ::Rails.root : (defined?(RAILS_ROOT) ? RAILS_ROOT : Dir.getwd)))
      end

      def threadsafe_enabled?
        rails_env = config.webxml.rails.env
        begin
          unless IO.readlines("config/environments/#{rails_env}.rb").grep(/^\s*config\.threadsafe!/).empty? &&
              IO.readlines("config/environment.rb").grep(/^\s*config\.threadsafe!/).empty?
            return true
          end
        rescue
        end
      end

      def rails_major_version(default = 0)
        begin
          File.open("#{ENV['BUNDLE_GEMFILE'] || 'Gemfile'}.lock") do |file|
            file.each_line do |line|
              match = line.match( /^\s*rails\s\(\s*(\d)\.\d+\.\d+.*\)$/ )
              return match[1].to_i if match
            end
          end
        rescue
        end
        default
      end
    end
  end
end
