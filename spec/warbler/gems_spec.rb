#--
# (c) Copyright 2007-2008 Sun Microsystems, Inc.
# See the file LICENSES.txt included with the distribution for
# software license details.
#++

require File.dirname(__FILE__) + '/../spec_helper'

describe Warbler::Gems do
  it "should accept a hash for initialization" do
    gems = Warbler::Gems.new({"actionpack" => "1.2.3"})
    gems.should have_key("actionpack")
    gems["actionpack"].should == "1.2.3"
  end

  it "should accept an array for initialization" do
    gems = Warbler::Gems.new ["activerecord"]
    gems.should have_key("activerecord")
  end

  it "should allow gems with a version" do
    gems = Warbler::Gems.new
    gems["actionpack"] = "> 1.2.3"
    gems["actionpack"].should == "> 1.2.3"
  end

  it "should allow gems without an explicit version" do
    gems = Warbler::Gems.new
    gems << "actionpack"
    gems.should have_key("actionpack")
  end

  it "should allow to add gems" do
    gems = Warbler::Gems.new
    gems << "rails"
    gems += ["activerecord-jdbcmysql-adapter", "jdbc-mysql", "jruby-openssl"]
    ["rails", "activerecord-jdbcmysql-adapter", "jdbc-mysql", "jruby-openssl"].each {|g| gems.should have_key(g)}
  end
end
