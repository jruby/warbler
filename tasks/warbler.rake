#--
# Copyright (c) 2010 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

begin
  # First, make sure plugin directory is at the front of the load path
  # (to avoid picking up gem-installed warbler)
  $LOAD_PATH.unshift(File.dirname(__FILE__) + '/../lib')
  require 'warbler'
rescue LoadError
  # Next, try activating the gem
  gem 'warbler'
  require 'warbler'
end

Warbler::Task.new
