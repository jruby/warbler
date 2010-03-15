#--
# Copyright (c) 2010 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

# Warbler is a lightweight, flexible, Rake-based system for packaging your Rails apps
# into .war files.
module Warbler
  WARBLER_HOME = File.expand_path(File.dirname(__FILE__) + '/..') unless defined?(WARBLER_HOME)

  class << self
    attr_accessor :application
    attr_accessor :framework_detection
    attr_writer :project_application
  end

  def self.project_application
    application.load_project_rakefile if application
    @project_application || Rake.application
  end
  self.framework_detection = true
end

require 'warbler/gems'
require 'warbler/config'
require 'warbler/war'
require 'warbler/task'
require 'warbler/application'
require 'warbler/runtime'
require 'warbler/version'
