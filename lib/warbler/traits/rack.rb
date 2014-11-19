#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

module Warbler
  module Traits
    # The Rack trait adds config.ru to a Rack-based war project.
    class Rack
      include Trait

      def self.detect?
        !Rails.detect? && (File.exist?("config.ru") || !Dir['*/config.ru'].empty?)
      end

      def self.requirements
        [ Traits::War ]
      end

      def before_configure
        config.webxml.booter = :rack
        config.webinf_files += [FileList['config.ru', '*/config.ru'].detect {|f| File.exist?(f)}]
        config.webxml.rack.env = ENV['RACK_ENV'] || 'production'
      end

      def after_configure
        config.init_contents << "#{config.warbler_templates}/rack.erb"
      end
    end
  end
end
