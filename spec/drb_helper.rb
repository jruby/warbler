#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'rubygems'
require 'drb'
require 'stringio'
require 'warbler'

class Warbler::Config
  include DRb::DRbUndumped
end

class Warbler::Jar
  include DRb::DRbUndumped
end

class WarblerDrbServer
  def initialize
    @output = StringIO.new
    $stdout = $stderr = @output
  end

  def config(config_proc = nil)
    @config ||= begin 
      Warbler::Config.new do |config| 
        config_proc && config_proc.call(config)
      end
    end
  end

  def ready?
    true
  end

  def jar
    @jar ||= Warbler::Jar.new
  end

  def run_task(t)
    @task ||= Warbler::Task.new "warble", config
    Rake::Task[t].invoke
  end

  def stop
    DRb.stop_service
  end
end

require File.expand_path('drb_default_id_conv', File.dirname(__FILE__))

server = WarblerDrbServer.new
service = DRb.start_service 'druby://127.0.0.1:7890', server
service.thread.join

