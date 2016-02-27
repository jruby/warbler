#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

module Warbler
  module RakeHelper

    def self.included(base)
      base.class_eval do
        include Rake::DSL if defined?(Rake::DSL)
        include Rake::FileUtilsExt # includes FileUtils
      end
    end

    def self.extended(base)
      base.extend Rake::DSL if defined?(Rake::DSL)
      base.extend Rake::FileUtilsExt
    end

    private

    def silent?
      Rake.application.options.silent rescue nil
    end

  end
end
