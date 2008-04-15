#--
# (c) Copyright 2007-2008 Sun Microsystems, Inc.
# See the file LICENSES.txt included with the distribution for
# software license details.
#++

class WarbleGenerator < Rails::Generator::Base
  def manifest
    record do |m|
      m.directory 'config'
      m.template 'warble.rb', File.join('config', 'warble.rb')
    end
  end
  
  protected
  def banner
    "Usage: #{$0} warble"
  end  
end