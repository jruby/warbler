#--
# Copyright (c) 2010 Engine Yard, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.dirname(__FILE__) + '/../spec_helper'

describe Warbler::War do
  before(:each) do
    @rake = Rake::Application.new
    Rake.application = @rake
    verbose(false)
    @pwd = Dir.getwd
    Dir.chdir("spec/sample")
    mkdir_p "log"
    touch "log/test.log"
    @config = Warbler::Config.new do |config|
      config.war_name = "warbler"
      config.gems = ["rake"]
      config.webxml.jruby.max.runtimes = 5
    end
    @war = Warbler::War.new
  end

  after(:each) do
    rm_rf "log"
    rm_rf ".bundle"
    rm_f FileList["*.war", "config.ru", "*web.xml*", "config/web.xml*",
                  "config/warble.rb", "file.txt", 'manifest', 'Gemfile*']
    Dir.chdir(@pwd)
  end

  def file_list(regex)
    @war.files.keys.select {|f| f =~ regex }
  end

  it "should collect files in public" do
    @war.apply(@config)
    file_list(%r{^index\.html}).should_not be_empty
  end

  it "should collect gem files" do
    @config.gems << "rake"
    @war.apply(@config)
    file_list(%r{WEB-INF/gems/gems/rake.*/lib/rake.rb}).should_not be_empty
    file_list(%r{WEB-INF/gems/specifications/rake.*\.gemspec}).should_not be_empty
  end

  it "should not include log files by default" do
    @war.apply(@config)
    file_list(%r{WEB-INF/log}).should_not be_empty
    file_list(%r{WEB-INF/log/.*\.log}).should be_empty
  end

  def expand_webxml
    @war.apply(@config)
    @war.files.should include("WEB-INF/web.xml")
    require 'rexml/document'
    REXML::Document.new(@war.files["WEB-INF/web.xml"]).root.elements
  end

  it "should create a web.xml file" do
    elements = expand_webxml
    elements.to_a(
      "context-param/param-name[text()='jruby.max.runtimes']"
      ).should_not be_empty
    elements.to_a(
      "context-param/param-name[text()='jruby.max.runtimes']/../param-value"
      ).first.text.should == "5"
  end

  it "should include custom context parameters in web.xml" do
    @config.webxml.some.custom.config = "myconfig"
    elements = expand_webxml
    elements.to_a(
      "context-param/param-name[text()='some.custom.config']"
      ).should_not be_empty
    elements.to_a(
      "context-param/param-name[text()='some.custom.config']/../param-value"
      ).first.text.should == "myconfig"
  end

  it "should allow one jndi resource to be included" do
    @config.webxml.jndi = 'jndi/rails'
    elements = expand_webxml
    elements.to_a(
      "resource-ref/res-ref-name[text()='jndi/rails']"
      ).should_not be_empty
  end

  it "should allow multiple jndi resources to be included" do
    @config.webxml.jndi = ['jndi/rails1', 'jndi/rails2']
    elements = expand_webxml
    elements.to_a(
      "resource-ref/res-ref-name[text()='jndi/rails1']"
      ).should_not be_empty
    elements.to_a(
      "resource-ref/res-ref-name[text()='jndi/rails2']"
      ).should_not be_empty
  end

  it "should not include any ignored context parameters" do
    @config.webxml.foo = "bar"
    @config.webxml.ignored << "foo"
    elements = expand_webxml
    elements.to_a(
      "context-param/param-name[text()='foo']"
      ).should be_empty
    elements.to_a(
      "context-param/param-name[text()='ignored']"
      ).should be_empty
    elements.to_a(
      "context-param/param-name[text()='jndi']"
      ).should be_empty
  end

  it "should use a config/web.xml if it exists" do
    mkdir_p "config"
    touch "config/web.xml"
    @war.apply(Warbler::Config.new)
    @war.files["WEB-INF/web.xml"].should == "config/web.xml"
  end

  it "should use a config/web.xml.erb if it exists" do
    mkdir_p "config"
    File.open("config/web.xml.erb", "w") {|f| f << "Hi <%= webxml.public.root %>" }
    @war.apply(Warbler::Config.new)
    @war.files["WEB-INF/web.xml"].should_not be_nil
    @war.files["WEB-INF/web.xml"].read.should == "Hi /"
  end

  it "should collect java libraries" do
    @war.apply(@config)
    file_list(%r{WEB-INF/lib/jruby-.*\.jar$}).should_not be_empty
  end

  it "should collect application files" do
    @war.apply(@config)
    file_list(%r{WEB-INF/app$}).should_not be_empty
    file_list(%r{WEB-INF/config$}).should_not be_empty
    file_list(%r{WEB-INF/lib$}).should_not be_empty
  end

  it "should accept an autodeploy directory where the war should be created" do
    require 'tmpdir'
    @config.autodeploy_dir = Dir::tmpdir
    touch "file.txt"
    @war.files["file.txt"] = "file.txt"
    silence { @war.create(@config) }
    File.exist?(File.join("#{Dir::tmpdir}","warbler.war")).should == true
  end

  it "should accept a custom manifest file" do
    touch 'manifest'
    @config.manifest_file = 'manifest'
    @war.apply(@config)
    @war.files['META-INF/MANIFEST.MF'].should == "manifest"
  end

  it "should not add a manifest if one already exists" do
    @war.files['META-INF/MANIFEST.MF'] = 'manifest'
    @war.add_manifest(@config)
    @war.files['META-INF/MANIFEST.MF'].should == "manifest"
  end

  it "should be able to exclude files from the .war" do
    @config.excludes += FileList['lib/tasks/utils.rake']
    @war.apply(@config)
    file_list(%r{lib/tasks/utils.rake}).should be_empty
  end

  it "should read configuration from #{Warbler::Config::FILE}" do
    mkdir_p "config"
    File.open(Warbler::Config::FILE, "w") do |dest|
      contents =
        File.open("#{Warbler::WARBLER_HOME}/warble.rb") do |src|
          src.read
        end
      dest << contents.sub(/# config\.war_name/, 'config.war_name'
        ).sub(/# config.gems << "tzinfo"/, 'config.gems = []')
    end
    t = Warbler::Task.new "warble"
    t.config.war_name.should == "mywar"
  end

  it "should fail if a gem is requested that is not installed" do
    @config.gems = ["nonexistent-gem"]
    lambda {
      Warbler::Task.new "warble", @config
      @war.apply(@config)
    }.should raise_error
  end

  it "should allow specification of dependency by Gem::Dependency" do
    spec = mock "gem spec"
    spec.stub!(:full_name).and_return "hpricot-0.6.157"
    spec.stub!(:full_gem_path).and_return "hpricot-0.6.157"
    spec.stub!(:loaded_from).and_return "hpricot.gemspec"
    spec.stub!(:files).and_return ["Rakefile"]
    spec.stub!(:dependencies).and_return []
    Gem.source_index.should_receive(:search).and_return do |gem|
      gem.name.should == "hpricot"
      [spec]
    end
    @config.gems = [Gem::Dependency.new("hpricot", "> 0.6")]
    @war.apply(@config)
  end

  it "should copy loose java classes to WEB-INF/classes" do
    @config.java_classes = FileList["Rakefile"]
    @war.apply(@config)
    file_list(%r{WEB-INF/classes/Rakefile$}).should_not be_empty
  end

  def mock_rails_module
    rails = Module.new
    Object.const_set("Rails", rails)
    version = Module.new
    rails.const_set("VERSION", version)
    version.const_set("STRING", "2.1.0")
    rails
  end

  def mock_merb_module
    merb = Module.new
    silence { Object.const_set("Merb", merb) }
    boot_loader = Module.new
    merb.const_set("BootLoader", boot_loader)
    merb.const_set("VERSION", "1.0")
    dependencies = Class.new do
      @@dependencies = []
      def self.dependencies
        @@dependencies
      end
      def self.dependencies=(deps)
        @@dependencies = deps
      end
    end
    boot_loader.const_set("Dependencies", dependencies)
    dependencies
  end

  it "should auto-detect a Rails application" do
    task :environment do
      mock_rails_module
    end
    @config = Warbler::Config.new
    @config.webxml.booter.should == :rails
    @config.gems["rails"].should == "2.1.0"
  end

  it "should provide Rails gems by default, unless vendor/rails is present" do
    rails = nil
    task :environment do
      rails = mock_rails_module
    end

    config = Warbler::Config.new
    config.gems.should have_key("rails")

    mkdir_p "vendor/rails"
    config = Warbler::Config.new
    config.gems.should be_empty

    rm_rf "vendor/rails"
    rails.stub!(:vendor_rails?).and_return true
    config = Warbler::Config.new
    config.gems.should be_empty
  end

  it "should not try to autodetect frameworks when Warbler.framework_detection is false" do
    begin
      Warbler.framework_detection = false
      task :environment
      config = Warbler::Config.new
      config.webxml.booter.should_not == :rails
      t = Rake::Task['environment']
      class << t; public :instance_variable_get; end
      t.instance_variable_get("@already_invoked").should == false
    ensure
      Warbler.framework_detection = true
    end
  end

  it "should auto-detect a Merb application" do
    task :merb_env do
      mock_merb_module
    end
    @config = Warbler::Config.new
    @config.webxml.booter.should == :merb
    @config.gems.keys.should_not include("rails")
  end

  it "should auto-detect a Rack application with a config.ru file" do
    rackup = "run Proc.new {|env| [200, {}, ['Hello World']]}"
    File.open("config.ru", "w") {|f| f << rackup }
    @config = Warbler::Config.new
    @config.webxml.booter.should == :rack
    @config.webxml.rackup.should == rackup
  end

  it "should automatically add Rails.configuration.gems to the list of gems" do
    task :environment do
      rails = mock_rails_module
      config = mock "config"
      rails.stub!(:configuration).and_return(config)
      gem = mock "gem"
      gem.stub!(:name).and_return "hpricot"
      gem.stub!(:requirement).and_return Gem::Requirement.new("=0.6")
      config.stub!(:gems).and_return [gem]
    end

    @config = Warbler::Config.new
    @config.webxml.booter.should == :rails
    @config.gems.keys.should include(Gem::Dependency.new("hpricot", Gem::Requirement.new("=0.6")))
  end

  it "should automatically add Merb::BootLoader::Dependencies.dependencies to the list of gems" do
    task :merb_env do
      deps = mock_merb_module
      deps.dependencies = [Gem::Dependency.new("merb-core", ">= 1.0.6.1")]
    end
    @config = Warbler::Config.new
    @config.webxml.booter.should == :merb
    @config.gems.keys.should include(Gem::Dependency.new("merb-core", ">= 1.0.6.1"))
  end

  it "should skip Merb development dependencies" do
    task :merb_env do
      deps = mock_merb_module
      deps.dependencies = [Gem::Dependency.new("rake", "= #{RAKEVERSION}", :development)]
    end
    @war.apply(Warbler::Config.new)
    file_list(/rake-#{RAKEVERSION}/).should be_empty
  end

  it "should warn about using Merb < 1.0" do
    task :merb_env do
      silence { Object.const_set("Merb", Module.new) }
    end
    @config = silence { Warbler::Config.new }
    @config.webxml.booter.should == :merb
  end

  it "should set the jruby max runtimes to 1 when MT Rails is detected" do
    task :environment do
      rails = mock_rails_module
      config = mock "config"
      rails.stub!(:configuration).and_return(config)
      config.stub!(:threadsafe!)
      config.should_receive(:allow_concurrency).and_return true
      config.should_receive(:preload_frameworks).and_return true
    end
    @config = Warbler::Config.new
    @config.webxml.booter.should == :rails
    @config.webxml.jruby.max.runtimes.should == 1
  end

  it "should skip directories that don't exist in config.dirs and print a warning" do
    @config.dirs = %w(lib notexist)
    silence { @war.apply(@config) }
    file_list(%r{WEB-INF/lib}).should_not be_empty
    file_list(%r{WEB-INF/notexist}).should be_empty
  end

  it "should write gems to location specified by gem_path" do
    @config = Warbler::Config.new {|c| c.gem_path = "/WEB-INF/jewels"; c.gems << 'rake' }
    elements = expand_webxml
    file_list(%r{WEB-INF/jewels}).should_not be_empty
    elements.to_a(
      "context-param/param-name[text()='gem.path']"
      ).should_not be_empty
    elements.to_a(
      "context-param/param-name[text()='gem.path']/../param-value"
      ).first.text.should == "/WEB-INF/jewels"

  end

  it "should detect a Bundler Gemfile and process only its gems" do
    File.open("Gemfile", "w") {|f| f << "gem 'rspec'"}
    @war.apply(Warbler::Config.new {|c| c.gems << "rake"})
    file_list(%r{WEB-INF/Gemfile}).should_not be_empty
    file_list(%r{WEB-INF/gems/specifications/rspec}).should_not be_empty
    file_list(%r{WEB-INF/gems/specifications/rake}).should be_empty
  end

  it "should write a Bundler environment file into the war" do
    File.open("Gemfile", "w") {|f| f << "gem 'rspec'"}
    @war.apply(Warbler::Config.new)
    file_list(%r{WEB-INF/\.bundle/environment\.rb}).should_not be_empty
  end

  it "should allow overriding of the gem path when using Bundler" do
    File.open("Gemfile", "w") {|f| f << "gem 'rspec'"}
    @war.apply(Warbler::Config.new {|c| c.gem_path = '/WEB-INF/jewels' })
    file_list(%r{WEB-INF/jewels/specifications/rspec}).should_not be_empty
    IO.readlines(".bundle/war-environment.rb").grep(/rspec/).last.should =~ %r{jewels/specifications}m
  end

  it "should not let the framework load Bundler from the locked environment" do
    task :environment do
      File.exist?('.bundle/environment.rb').should_not be_true
      mock_rails_module
    end

    File.open("Gemfile", "w") {|f| f << "gem 'rspec'"}
    `ruby -S bundle lock`
    File.exist?('.bundle/environment.rb').should be_true
    @war.apply(Warbler::Config.new)
    hash = eval("[" + IO.readlines(".bundle/environment.rb").grep(/rspec/).last + "]").first
    hash[:load_paths].each {|p| File.exist?(p).should be_true }
  end

  it "should allow adding additional WEB-INF files via config.webinf_files" do
    File.open("myserver-web.xml", "w") do |f|
      f << "<web-app></web-app>"
    end
    @war.apply(Warbler::Config.new {|c| c.webinf_files = FileList['myserver-web.xml'] })
    file_list(%r{WEB-INF/myserver-web.xml}).should_not be_empty
  end

  it "should allow expanding of additional WEB-INF files via config.webinf_files" do
    File.open("myserver-web.xml.erb", "w") do |f|
      f << "<web-app><%= webxml.rails.env %></web-app>"
    end
    @war.apply(Warbler::Config.new {|c| c.webinf_files = FileList['myserver-web.xml.erb'] })
    file_list(%r{WEB-INF/myserver-web.xml}).should_not be_empty
    @war.files['WEB-INF/myserver-web.xml'].read.should =~ /web-app.*production/
  end
end
