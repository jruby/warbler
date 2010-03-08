#--
# Copyright (c) 2010 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
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
