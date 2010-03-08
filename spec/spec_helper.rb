#--
# Copyright (c) 2010 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'rubygems'
require 'spec'

$LOAD_PATH.unshift File.dirname(__FILE__) + '/../lib'
require 'warbler'

raise %{Error: detected running Warbler specs in a Rails app;
Warbler specs are destructive to application directories.} if File.directory?("app")

def silence(io = nil)
  require 'stringio'
  old_stdout = $stdout
  old_stderr = $stderr
  $stdout = io || StringIO.new
  $stderr = io || StringIO.new
  yield
ensure
  $stdout = old_stdout
  $stderr = old_stderr
end

def capture(&block)
  require 'stringio'
  io = StringIO.new
  silence(io, &block)
  io.string
end

Spec::Runner.configure do |config|
  config.after(:each) do
    class << Object
      public :remove_const
    end
    Object.remove_const("Rails") rescue nil
    rm_rf "vendor"
  end
end
