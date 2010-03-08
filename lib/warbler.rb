#--
# (c) Copyright (c) 2010 Engine Yard, Inc.
# (c) Copyright (c) 2007-2009 Sun Microsystems, Inc.
# (c) This source code is available under the MIT license.
# (c) See the file LICENSE.txt for details.
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