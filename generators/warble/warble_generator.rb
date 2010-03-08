#--
# (c) Copyright (c) 2010 Engine Yard, Inc.
# (c) Copyright (c) 2007-2009 Sun Microsystems, Inc.
# (c) This source code is available under the MIT license.
# (c) See the file LICENSE.txt for details.
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