#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.expand_path('../../spec_helper', __FILE__)

describe Warbler::Gems do
  it "should accept a hash for initialization" do
    gems = Warbler::Gems.new({"actionpack" => "1.2.3"})
    expect(gems).to have_key("actionpack")
    expect(gems["actionpack"]).to eq "1.2.3"
  end

  it "should accept an array for initialization" do
    gems = Warbler::Gems.new ["activerecord"]
    expect(gems).to have_key("activerecord")
  end

  it "should allow gems with a version" do
    gems = Warbler::Gems.new
    gems["actionpack"] = "> 1.2.3"
    expect(gems["actionpack"]).to eq "> 1.2.3"
  end

  it "should allow gems without an explicit version" do
    gems = Warbler::Gems.new
    gems << "actionpack"
    expect(gems).to have_key("actionpack")
  end

  it "should allow to add gems" do
    gems = Warbler::Gems.new
    gems << "rails"
    gems += ["activerecord-jdbcmysql-adapter", "jdbc-mysql", "jruby-openssl"]
    ["rails", "activerecord-jdbcmysql-adapter", "jdbc-mysql", "jruby-openssl"].each {|g| expect(gems).to have_key(g)}
  end
end
