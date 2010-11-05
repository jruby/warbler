#--
# Copyright (c) 2010 Engine Yard, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

module Warbler
  module Traits
    class Rack
      include Trait

      def self.detect?
        !Rails.detect? && (File.exist?("config.ru") || !Dir['*/config.ru'].empty?)
      end

      def self.requires?(trait)
        trait == Traits::War
      end

      def before_configure
        config.webxml.booter = :rack
        config.webinf_files += [FileList['config.ru', '*/config.ru'].detect {|f| File.exist?(f)}]
      end

      def after_configure
        config.init_contents << "#{config.warbler_templates}/rack.erb"
      end
    end
  end
end