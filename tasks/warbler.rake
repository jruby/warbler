#--
# (c) Copyright 2007 Nick Sieger <nicksieger@gmail.com>
# See the file LICENSES.txt included with the distribution for
# software license details.
#++

begin
  # First, try w/o activating gem or touching load path
  require 'warbler'
rescue LoadError
  begin
    # Next, try activating the gem
    gem 'warbler'
    require 'warbler'
  rescue Gem::LoadError
    # Last, add our lib dir to the load path, and try again
    $LOAD_PATH.unshift(File.dirname(__FILE__) + '/../lib')
    require 'warbler'
  end
end

Warbler::Task.new