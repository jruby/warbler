# (c) Copyright 2007 Nick Sieger <nicksieger@gmail.com>
# See the file LICENSES.txt included with the distribution for
# software license details.

class WarblerGenerator < Rails::Generator::Base
  def manifest
    record do |m|
      m.directory 'config'
      m.template 'warble.rb', File.join('config', 'warble.rb')
    end
  end
  
  protected
  def banner
    "Usage: #{$0} warbler"
  end  
end