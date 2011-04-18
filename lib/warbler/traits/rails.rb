#--
# Copyright (c) 2010-2011 Engine Yard, Inc.
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
        File.exist?("config/environment.rb")
      end

      def self.requires?(trait)
        trait == Traits::War
      end

      def before_configure
        config.jar_name = default_app_name
        config.webxml.rails.env = ENV['RAILS_ENV'] || 'production'

        return unless Warbler.framework_detection
        return false unless task = Warbler.project_application.lookup("environment")

        task.invoke rescue nil
        return false unless defined?(::Rails)

        config.dirs << "tmp" if File.directory?("tmp")
        config.webxml.booter = :rails
        unless (defined?(::Rails.vendor_rails?) && ::Rails.vendor_rails?) || File.directory?("vendor/rails")
          config.gems["rails"] = ::Rails::VERSION::STRING
        end
        if defined?(::Rails.configuration.gems)
          ::Rails.configuration.gems.each do |g|
            config.gems << Gem::Dependency.new(g.name, g.requirement) if Dir["vendor/gems/#{g.name}*"].empty?
          end
        end
        if defined?(::Rails.configuration.threadsafe!) &&
            (defined?(::Rails.configuration.allow_concurrency) && # Rails 3
             ::Rails.configuration.allow_concurrency && ::Rails.configuration.preload_frameworks) ||
          (defined?(::Rails.configuration.action_controller.allow_concurrency) && # Rails 2
           ::Rails.configuration.action_controller.allow_concurrency && ::Rails.configuration.action_controller.preload_frameworks)
          config.webxml.jruby.max.runtimes = 1
        end
      end

      def after_configure
        config.init_contents << "#{config.warbler_templates}/rails.erb"
      end


      def default_app_name
        File.basename(File.expand_path(defined?(::Rails.root) ? ::Rails.root : (defined?(RAILS_ROOT) ? RAILS_ROOT : Dir.getwd)))
      end
    end
  end
end
