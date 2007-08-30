# (c) Copyright 2007 Nick Sieger <nicksieger@gmail.com>
# See the file LICENSES.txt included with the distribution for
# software license details.

begin
  gem 'warbler'
  require 'warbler'
rescue Gem::LoadError, LoadError
  $LOAD_PATH.unshift(File.dirname(__FILE__) + '/../lib')
  require 'warbler'
end

Warbler::Task.new