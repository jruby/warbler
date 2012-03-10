#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

module Warbler
  # This module exists for compatibility with Rake 0.9.
  module RakeHelper
    def self.included(base)
      base.class_eval do
        include Rake::DSL if defined?(Rake::DSL)
        if defined?(Rake::FileUtilsExt)
          include FileUtils
          include Rake::FileUtilsExt
        end
      end
    end

    def self.extended(base)
      base.extend Rake::DSL if defined?(Rake::DSL)
      if defined?(Rake::FileUtilsExt)
        base.extend FileUtils
        base.extend Rake::FileUtilsExt
      end
    end
  end
end
