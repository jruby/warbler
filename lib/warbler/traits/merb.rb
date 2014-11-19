#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

module Warbler
  module Traits
    # The Merb trait adds Merb::BootLoader gem dependencies to the project.
    class Merb
      include Trait

      def self.detect?
        File.exist?("config/init.rb")
      end

      def self.requirements
        [ Traits::War ]
      end

      def before_configure
        return false unless task = Warbler.project_application.lookup("merb_env")
        task.invoke rescue nil
        return false unless defined?(::Merb)
        config.webxml.booter = :merb
        if defined?(::Merb::BootLoader::Dependencies.dependencies)
          ::Merb::BootLoader::Dependencies.dependencies.each {|g| config.gems << g }
        else
          warn "unable to auto-detect Merb dependencies; upgrade to Merb 1.0 or greater"
        end
      end
    end
  end
end
