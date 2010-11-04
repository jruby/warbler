module Warbler
  module Traits
    class Rails
      include Trait

      def before_configure
        config.app_root = default_app_root
        config.jar_name = File.basename(config.app_root)
      end

      def default_app_root
        File.expand_path(defined?(::Rails.root) ? ::Rails.root : (defined?(RAILS_ROOT) ? RAILS_ROOT : Dir.getwd))
      end
    end
  end
end
