require 'ostruct'

module Warbler
  module Traits
    class War
      include Trait

      DEFAULT_GEM_PATH = '/WEB-INF/gems'

      def before_configure
        config.gem_path = DEFAULT_GEM_PATH
        config.pathmaps = default_pathmaps
      end

      def after_configure
        update_gem_path
      end

      def default_pathmaps
        p = OpenStruct.new
        p.public_html  = ["%{public/,}p"]
        p.java_libs    = ["WEB-INF/lib/%f"]
        p.java_classes = ["WEB-INF/classes/%p"]
        p.application  = ["WEB-INF/%p"]
        p.webinf       = ["WEB-INF/%{.erb$,}f"]
        p.gemspecs     = ["#{config.relative_gem_path}/specifications/%f"]
        p.gems         = ["#{config.relative_gem_path}/gems/%p"]
        p
      end

      def update_gem_path
        if config.gem_path != DEFAULT_GEM_PATH
          config.gem_path = "/#{config.gem_path}" unless config.gem_path =~ %r{^/}
          sub_gem_path = config.gem_path[1..-1]
          config.pathmaps.gemspecs.each {|p| p.sub!(DEFAULT_GEM_PATH[1..-1], sub_gem_path)}
          config.pathmaps.gems.each {|p| p.sub!(DEFAULT_GEM_PATH[1..-1], sub_gem_path)}
          config.webxml["gem"]["path"] = config.gem_path
        end
      end
    end
  end
end
