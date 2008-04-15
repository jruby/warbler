#--
# (c) Copyright 2007-2008 Sun Microsystems, Inc.
# See the file LICENSES.txt included with the distribution for
# software license details.
#++

# Warbler is a lightweight, flexible, Rake-based system for packaging your Rails apps
# into .war files.
module Warbler
  WARBLER_HOME = File.expand_path(File.dirname(__FILE__) + '/..') unless defined?(WARBLER_HOME)
end

require 'warbler/gems'
require 'warbler/config'
require 'warbler/task'
require 'warbler/version'