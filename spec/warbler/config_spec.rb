#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.expand_path('../../spec_helper', __FILE__)

describe Warbler::Config do
  before :each do
    verbose(false)
  end

  context "in an unknown application" do
    run_in_directory 'spec/sample_war/tmp'

    after :each do
      rm_rf "../tmp"
    end

    it "has suitable default values" do
      config = Warbler::Config.new
      expect(config.includes).to be_empty
      expect(config.jar_name.size).to be_positive
      expect(config.override_gem_home).to be true
    end
  end

  context "in a web application" do
    run_in_directory 'spec/sample_war'

    after :each do
      rm_f "vendor/test.log"
    end

    it "should have suitable default values" do
      config = Warbler::Config.new
      expect(config.dirs).to include(*Warbler::Config::TOP_DIRS.select{|d| File.directory?(d)})
      expect(config.excludes).to be_empty
      expect(config.java_libs).to_not be_empty
      expect(config.jar_name.size).to be_positive
      expect(config.webxml).to be_kind_of(OpenStruct)
      expect(config.pathmaps).to be_kind_of(OpenStruct)
      expect(config.pathmaps.public_html).to include("%{public/,}p")
      expect(config.override_gem_home).to be true
    end

    it "should allow configuration through an initializer block" do
      config = Warbler::Config.new do |c|
        c.jar_name = "mywar"
      end
      expect(config.jar_name).to eq "mywar"
    end

    it "should allow gems to be added/changed with =, +=, -=, <<" do
      config = Warbler::Config.new do |c|
        c.gems += ["activerecord-jdbc-adapter"]
        c.gems -= ["rails"]
        c.gems << "tzinfo"
        c.gems = ["camping"]
      end
    end

    it "should exclude log files by default" do
      mkdir_p "vendor"
      touch "vendor/test.log"
      config = Warbler::Config.new
      expect(config.exclude_logs).to eq true
      expect(config.excludes.include?("vendor/test.log")).to eq true
    end

    it "should include log files if exclude_logs is false" do
      mkdir_p "vendor"
      touch "vendor/test.log"
      config = Warbler::Config.new {|c| c.exclude_logs = false }
      expect(config.exclude_logs).to eq false
      expect(config.excludes.include?("vendor/test.log")).to eq false
    end

    it "should exclude Warbler itself when run as a plugin" do
      config = Warbler::Config.new
      expect(config.excludes.include?("vendor/plugins/warbler")).to eq false
      config = Warbler::Config.new File.join(Dir.getwd, "vendor", "plugins", "warbler")
      expect(config.excludes.include?("vendor/plugins/warbler")).to eq true
    end

    it "should generate context parameters from the webxml openstruct" do
      config = Warbler::Config.new
      config.webxml.a.b.c = "123"
      config.webxml.com.example.config = "blah"
      config.webxml.rails.env = 'staging'
      config.webxml.jruby.min.runtimes = 2
      config.webxml.jruby.max.runtimes = 4
      config.webxml['org']['jruby']['rack'] = "rails"
      params = config.webxml.context_params
      expect(params).to have_key('a.b.c')
      expect(params).to have_key('rails.env')
      expect(params).to have_key('jruby.min.runtimes')
      expect(params).to have_key('jruby.max.runtimes')
      expect(params['a.b.c']).to eq "123"
      expect(params['com.example.config']).to eq "blah"
      expect(params['rails.env']).to eq "staging"
      expect(params['jruby.min.runtimes']).to eq "2"
      expect(params['jruby.max.runtimes']).to eq "4"
      expect(params['org.jruby.rack']).to eq "rails"
    end

    it "should determine the context listener from the webxml.booter parameter" do
      config = Warbler::Config.new
      config.webxml.booter = :rack
      expect(config.webxml.servlet_context_listener).to eq "org.jruby.rack.RackServletContextListener"
      config.webxml.booter = :rails
      expect(config.webxml.servlet_context_listener).to eq "org.jruby.rack.rails.RailsServletContextListener"
      config = Warbler::Config.new
      expect(config.webxml.servlet_context_listener).to eq "org.jruby.rack.rails.RailsServletContextListener"
    end

    it "allows for adjusting of context listeners" do
      config = Warbler::Config.new
      config.webxml.booter = :rack
      expect(config.webxml.servlet_context_listeners).to eq [ 'org.jruby.rack.RackServletContextListener' ]
      config.webxml.servlet_context_listeners.clear
      expect(config.webxml.servlet_context_listeners).to eq [ ]

      config = Warbler::Config.new
      config.webxml.booter = :rails
      config.webxml.servlet_context_listeners << 'org.kares.jruby.rack.WorkerContextListener'
      expect(config.webxml.servlet_context_listeners).to eq [ 'org.jruby.rack.rails.RailsServletContextListener', 'org.kares.jruby.rack.WorkerContextListener' ]

      expect(config.webxml.context_params).to_not have_key('servlet_context_listener')
    end

    it "provides rack filter defaults" do
      config = Warbler::Config.new
      expect(config.webxml.servlet_filter).to eq 'org.jruby.rack.RackFilter'
      expect(config.webxml.servlet_filter_name).to eq 'RackFilter'
      expect(config.webxml.servlet_filter_url_pattern).to eq '/*'
      config.webxml.servlet_filter_async
    end

    it "should not include ignored webxml keys in the context params hash" do
      config = Warbler::Config.new
      config.webxml.booter = :rack
      expect(config.webxml.context_params).to_not have_key('booter')
      expect(Warbler::Config.new.webxml.context_params).to_not have_key('ignored')
      expect(Warbler::Config.new.webxml.context_params).to_not have_key('jndi')
    end

    it "should have a helpful string representation for an empty key" do
      expect(Warbler::Config.new.webxml.missing_key.to_s).to match /No value for 'missing_key' found/
    end

    it "should HTML-escape all webxml keys and values" do
      config = Warbler::Config.new
      config.webxml.a["b&"].c = "123<hi>456"
      expect(config.webxml.context_params['a.b&amp;.c']).to eq "123&lt;hi&gt;456"
    end
  end
end
