#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

module Warbler
  module Traits
    # The JBundler trait uses JBundler to determine jar dependencies to
    # be added to the project.
    class JBundler
      include Trait
      include PathmapHelper

      def self.detect?
        File.exist?(ENV['JBUNDLE_JARFILE'] || "Jarfile")
      end

      def self.requirements
        [ Traits::War, Traits::Jar ]
      end

      def before_configure
        config.jbundler = true
      end

      def after_configure
        add_jbundler_jars if config.jbundler
      end

      def add_jbundler_jars
        require 'jbundler/config'
        classpath = ::JBundler::Config.new.classpath_file
        if File.exists?( classpath )
          require File.expand_path( classpath )
        else
          raise 'jbundler support needs jruby to create a local config: jruby -S jbundle install'
        end
        # use only the jars from jbundler and jruby
        config.java_libs += jruby_jars
        config.java_libs += JBUNDLER_CLASSPATH
        config.java_libs.uniq! {|lib| lib.split(File::SEPARATOR).last }
        config.init_contents << "#{config.warbler_templates}/jbundler.erb"
      end
    end
  end
end
