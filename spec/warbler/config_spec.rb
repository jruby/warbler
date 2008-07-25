#--
# (c) Copyright 2007-2008 Sun Microsystems, Inc.
# See the file LICENSES.txt included with the distribution for
# software license details.
#++

require File.dirname(__FILE__) + '/../spec_helper'

describe Warbler::Config do
  after(:each) do
    rm_rf "vendor"
  end

  it "should have suitable default values" do
    config = Warbler::Config.new
    config.staging_dir.should == "tmp/war"
    config.dirs.should include(*Warbler::Config::TOP_DIRS)
    config.includes.should be_empty
    config.java_libs.should_not be_empty
    config.war_name.size.should > 0
    config.webxml.should be_kind_of(OpenStruct)
    config.pathmaps.should be_kind_of(OpenStruct)
    config.pathmaps.public_html.should == ["%{public/,}p"]
  end

  it "should allow configuration through an initializer block" do
    config = Warbler::Config.new do |c|
      c.staging_dir = "/var/tmp"
      c.war_name = "mywar"
    end
    config.staging_dir.should == "/var/tmp"
    config.war_name.should == "mywar"
  end

  it "should provide Rails gems by default, unless vendor/rails is present" do
    config = Warbler::Config.new
    config.gems.should include("rails")

    mkdir_p "vendor/rails"
    config = Warbler::Config.new
    config.gems.should be_empty
  end

  it "should exclude log files by default" do
    mkdir_p "vendor"
    touch "vendor/test.log"
    config = Warbler::Config.new
    config.exclude_logs.should == true
    config.excludes.include?("vendor/test.log").should == true
  end

  it "should include log files if exclude_logs is false" do
    mkdir_p "vendor"
    touch "vendor/test.log"
    config = Warbler::Config.new {|c| c.exclude_logs = false }
    config.exclude_logs.should == false
    config.excludes.include?("vendor/test.log").should == false
  end

  it "should exclude Warbler itself when run as a plugin" do
    config = Warbler::Config.new
    config.excludes.include?("vendor/plugins/warbler").should == false
    config = Warbler::Config.new File.join(Dir.getwd, "vendor", "plugins", "warbler")
    config.excludes.include?("vendor/plugins/warbler").should == true
  end

  it "should generate context parameters from the webxml openstruct" do
    config = Warbler::Config.new
    config.webxml.a.b.c = "123"
    config.webxml.rails.env = 'staging'
    config.webxml.jruby.min.runtimes = 2
    config.webxml.jruby.max.runtimes = 4
    params = config.webxml.context_params
    params.should have_key('a.b.c')
    params.should have_key('rails.env')
    params.should have_key('jruby.min.runtimes')
    params.should have_key('jruby.max.runtimes')
    params['a.b.c'].should == "123"
    params['rails.env'].should == "staging"
    params['jruby.min.runtimes'].should == "2"
    params['jruby.max.runtimes'].should == "4"
  end

  it "should determine the context listener from the webxml.booter parameter" do
    config = Warbler::Config.new
    config.webxml.booter = :rack
    config.webxml.servlet_context_listener.should == "org.jruby.rack.RackServletContextListener"
    config = Warbler::Config.new
    config.webxml.booter = :merb
    config.webxml.servlet_context_listener.should == "org.jruby.rack.merb.MerbServletContextListener"
    config = Warbler::Config.new
    config.webxml.servlet_context_listener.should == "org.jruby.rack.rails.RailsServletContextListener"
  end

  it "should not include ignored webxml keys in the context params hash" do
    Warbler::Config.new.webxml.context_params.should_not have_key('ignored')
    Warbler::Config.new.webxml.context_params.should_not have_key('jndi')
    Warbler::Config.new.webxml.context_params.should_not have_key('booter')
  end

  it "should have a helpful string representation for an empty key" do
    Warbler::Config.new.webxml.missing_key.to_s.should =~ /No value for 'missing_key' found/
  end

  #it "should automatically gems used by the web application" do
  #  gem "actionpack"
  #  config = Warbler::Config.new
  #  config.gems.should include("actionpack")
  #end
end
