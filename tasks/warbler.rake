#--
# (c) Copyright 2007-2008 Sun Microsystems, Inc.
# See the file LICENSES.txt included with the distribution for
# software license details.
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