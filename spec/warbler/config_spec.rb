# (c) Copyright 2007 Nick Sieger <nicksieger@gmail.com>
# See the file LICENSES.txt included with the distribution for
# software license details.

require File.dirname(__FILE__) + '/../spec_helper'

describe Warbler::Config do
  it "should have suitable default values" do
    config = Warbler::Config.new
    config.staging_dir.should == "tmp/war"
    config.dirs.should include(*Warbler::Config::TOP_DIRS)
    config.includes.should be_empty
    config.java_libs.should_not be_empty
    config.gems.should be_empty
    config.war_name.size.should > 0
    config.webxml.should be_kind_of(OpenStruct)
    config.webxml.pool.should be_kind_of(OpenStruct)
  end

  it "should allow configuration through an initializer block" do
    config = Warbler::Config.new do |c|
      c.staging_dir = "/var/tmp"
      c.war_name = "mywar"
    end
    config.staging_dir.should == "/var/tmp"
    config.war_name.should == "mywar"
  end
end
