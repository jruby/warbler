#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

# Warbler is a lightweight, flexible, Rake-based system for packaging
# your Ruby applications into .jar or .war files.
module Warbler
  WARBLER_HOME = File.expand_path(File.dirname(__FILE__) + '/..') unless defined?(WARBLER_HOME)
  WARBLER_JAR = "#{WARBLER_HOME}/lib/warbler_jar.jar" unless defined?(WARBLER_JAR)

  class << self
    # An instance of Warbler::Application used by the +warble+ command.
    attr_accessor :application
    # Set Warbler.framework_detection to false to disable
    # auto-detection based on application configuration.
    attr_accessor :framework_detection
    attr_writer :project_application
  end

  # Warbler loads the project Rakefile in a separate Rake application
  # from the one where the Warbler tasks are run.
  def self.project_application
    application.load_project_rakefile if application
    @project_application || Rake.application
  end
  self.framework_detection = true
end

require 'warbler/version'
require 'warbler/executable_helper'
require 'warbler/rake_helper'
require 'warbler/pathmap_helper'
require 'warbler/platform_helper'
require 'warbler/bundler_helper'
require 'warbler/task'
require 'warbler/application'
require 'warbler/web_server'
