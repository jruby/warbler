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
    Dir.chdir("spec/sample_war")
    mkdir_p "log"
    touch "log/test.log"
    @config = Warbler::Config.new do |config|
      config.war_name = "warbler"
      config.gems = ["rake"]
      config.webxml.jruby.max.runtimes = 5
    end rescue nil
    @war = Warbler::War.new
    @env_save = {}
    (ENV.keys.grep(/BUNDLE/) + ["RUBYOPT", "GEM_PATH"]).each {|k| @env_save[k] = ENV[k]; ENV[k] = nil}
  end

  after(:each) do
    rm_rf FileList["log", ".bundle", "tmp/war"]
    rm_f FileList["*.war", "config.ru", "*web.xml*", "config/web.xml*", "config/warble.rb",
                  "file.txt", 'manifest', 'Gemfile*', 'MANIFEST.MF*', 'init.rb*']
    Dir.chdir(@pwd)
    @env_save.keys.each {|k| ENV[k] = @env_save[k]}
  end

  def file_list(regex)
    @war.files.keys.select {|f| f =~ regex }
  end

  it "detects a War trait" do
    @config.traits.should include(Warbler::Traits::War)
  end

  it "collects files in public" do
    @war.apply(@config)
    file_list(%r{^index\.html}).should_not be_empty
  end

  it "collects gem files" do
    @config.gems << "rake"
    @war.apply(@config)
    file_list(%r{WEB-INF/gems/gems/rake.*/lib/rake.rb}).should_not be_empty
    file_list(%r{WEB-INF/gems/specifications/rake.*\.gemspec}).should_not be_empty
  end

  it "does not include log files by default" do
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

  it "creates a web.xml file" do
    elements = expand_webxml
    elements.to_a(
      "context-param/param-name[text()='jruby.max.runtimes']"
      ).should_not be_empty
    elements.to_a(
      "context-param/param-name[text()='jruby.max.runtimes']/../param-value"
      ).first.text.should == "5"
  end

  it "includes custom context parameters in web.xml" do
    @config.webxml.some.custom.config = "myconfig"
    elements = expand_webxml
    elements.to_a(
      "context-param/param-name[text()='some.custom.config']"
      ).should_not be_empty
    elements.to_a(
      "context-param/param-name[text()='some.custom.config']/../param-value"
      ).first.text.should == "myconfig"
  end

  it "allows one jndi resource to be included" do
    @config.webxml.jndi = 'jndi/rails'
    elements = expand_webxml
    elements.to_a(
      "resource-ref/res-ref-name[text()='jndi/rails']"
      ).should_not be_empty
  end

  it "allows multiple jndi resources to be included" do
    @config.webxml.jndi = ['jndi/rails1', 'jndi/rails2']
    elements = expand_webxml
    elements.to_a(
      "resource-ref/res-ref-name[text()='jndi/rails1']"
      ).should_not be_empty
    elements.to_a(
      "resource-ref/res-ref-name[text()='jndi/rails2']"
      ).should_not be_empty
  end

  it "does not include any ignored context parameters" do
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

  it "uses a config/web.xml if it exists" do
    mkdir_p "config"
    touch "config/web.xml"
    @war.apply(Warbler::Config.new)
    @war.files["WEB-INF/web.xml"].should == "config/web.xml"
  end

  it "uses a config/web.xml.erb if it exists" do
    mkdir_p "config"
    File.open("config/web.xml.erb", "w") {|f| f << "Hi <%= webxml.public.root %>" }
    @war.apply(Warbler::Config.new)
    @war.files["WEB-INF/web.xml"].should_not be_nil
    @war.files["WEB-INF/web.xml"].read.should == "Hi /"
  end

  it "collects java libraries" do
    @war.apply(@config)
    file_list(%r{WEB-INF/lib/jruby-.*\.jar$}).should_not be_empty
  end

  it "collects application files" do
    @war.apply(@config)
    file_list(%r{WEB-INF/app$}).should_not be_empty
    file_list(%r{WEB-INF/config$}).should_not be_empty
    file_list(%r{WEB-INF/lib$}).should_not be_empty
  end

  it "accepts an autodeploy directory where the war should be created" do
    require 'tmpdir'
    @config.autodeploy_dir = Dir::tmpdir
    touch "file.txt"
    @war.files["file.txt"] = "file.txt"
    silence { @war.create(@config) }
    File.exist?(File.join("#{Dir::tmpdir}","warbler.war")).should == true
  end

  it "can exclude files from the .war" do
    @config.excludes += FileList['lib/tasks/utils.rake']
    @war.apply(@config)
    file_list(%r{lib/tasks/utils.rake}).should be_empty
  end

  it "reads configuration from #{Warbler::Config::FILE}" do
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

  it "fails if a gem is requested that is not installed" do
    @config.gems = ["nonexistent-gem"]
    lambda {
      Warbler::Task.new "warble", @config
      @war.apply(@config)
    }.should raise_error
  end

  it "allows specification of dependency by Gem::Dependency" do
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

  it "copies loose java classes to WEB-INF/classes" do
    @config.java_classes = FileList["Rakefile"]
    @war.apply(@config)
    file_list(%r{WEB-INF/classes/Rakefile$}).should_not be_empty
  end

  it "does not try to autodetect frameworks when Warbler.framework_detection is false" do
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

  context "in a Rails application" do
    before :each do
      @rails = nil
      task :environment do
        @rails = mock_rails_module
      end
    end

    def mock_rails_module
      rails = Module.new
      Object.const_set("Rails", rails)
      version = Module.new
      rails.const_set("VERSION", version)
      version.const_set("STRING", "2.1.0")
      rails
    end

    it "detects a Rails trait" do
      @config = Warbler::Config.new
      @config.traits.should include(Warbler::Traits::Rails)
    end

    it "auto-detects a Rails application" do
      @config = Warbler::Config.new
      @config.webxml.booter.should == :rails
      @config.gems["rails"].should == "2.1.0"
    end

    it "provides Rails gems by default, unless vendor/rails is present" do
      config = Warbler::Config.new
      config.gems.should have_key("rails")

      mkdir_p "vendor/rails"
      config = Warbler::Config.new
      config.gems.should be_empty

      rm_rf "vendor/rails"
      @rails.stub!(:vendor_rails?).and_return true
      config = Warbler::Config.new
      config.gems.should be_empty
    end

    it "automatically adds Rails.configuration.gems to the list of gems" do
      task :environment do
        config = mock "config"
        @rails.stub!(:configuration).and_return(config)
        gem = mock "gem"
        gem.stub!(:name).and_return "hpricot"
        gem.stub!(:requirement).and_return Gem::Requirement.new("=0.6")
        config.stub!(:gems).and_return [gem]
      end

      @config = Warbler::Config.new
      @config.webxml.booter.should == :rails
      @config.gems.keys.should include(Gem::Dependency.new("hpricot", Gem::Requirement.new("=0.6")))
    end

    it "sets the jruby max runtimes to 1 when MT Rails is detected" do
      task :environment do
        config = mock "config"
        @rails.stub!(:configuration).and_return(config)
        config.stub!(:threadsafe!)
        config.should_receive(:allow_concurrency).and_return true
        config.should_receive(:preload_frameworks).and_return true
      end

      @config = Warbler::Config.new
      @config.webxml.booter.should == :rails
      @config.webxml.jruby.max.runtimes.should == 1
    end

    it "adds RAILS_ENV to init.rb" do
      @config = Warbler::Config.new { |c| c.webxml.booter = :rails }
      @war.add_init_file(@config)
      contents = @war.files['META-INF/init.rb'].read
      contents.should =~ /ENV\['RAILS_ENV'\]/
      contents.should =~ /'production'/
    end
  end

  context "in a Merb application" do
    before :each do
      @merb = nil
      task :merb_env do
        @merb = mock_merb_module
      end
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

    it "detects a Merb trait" do
      @config = Warbler::Config.new
      @config.traits.should include(Warbler::Traits::Merb)
    end

    it "auto-detects a Merb application" do
      @config = Warbler::Config.new
      @config.webxml.booter.should == :merb
      @config.gems.keys.should_not include("rails")
    end

    it "automatically adds Merb::BootLoader::Dependencies.dependencies to the list of gems" do
      task :merb_env do
        @merb.dependencies = [Gem::Dependency.new("merb-core", ">= 1.0.6.1")]
      end
      @config = Warbler::Config.new
      @config.webxml.booter.should == :merb
      @config.gems.keys.should include(Gem::Dependency.new("merb-core", ">= 1.0.6.1"))
    end

    it "skips Merb development dependencies" do
      task :merb_env do
        @merb.dependencies = [Gem::Dependency.new("rake", "= #{RAKEVERSION}", :development)]
      end
      @war.apply(Warbler::Config.new)
      file_list(/rake-#{RAKEVERSION}/).should be_empty
    end

    it "warns about using Merb < 1.0" do
      task :merb_env do
        silence { Object.const_set("Merb", Module.new) }
      end
      @config = silence { Warbler::Config.new }
      @config.webxml.booter.should == :merb
    end
  end

  context "in a Rack application" do
    before :each do
      rackup = "run Proc.new {|env| [200, {}, ['Hello World']]}"
      File.open("config.ru", "w") {|f| f << rackup }
    end

    it "detects a Rack trait" do
      @config = Warbler::Config.new
      @config.traits.should include(Warbler::Traits::Rack)
    end

    it "auto-detects a Rack application with a config.ru file" do
      @config = Warbler::Config.new
      @war.apply(@config)
      @war.files['WEB-INF/config.ru'].should == 'config.ru'
    end

    it "adds RACK_ENV to init.rb" do
      @config = Warbler::Config.new
      @war.add_init_file(@config)
      contents = @war.files['META-INF/init.rb'].read
      contents.should =~ /ENV\['RACK_ENV'\]/
      contents.should =~ /'production'/
    end
  end

  context "with Bundler" do
    before :each do
      File.open("Gemfile", "w") {|f| f << "gem 'rspec'"}
    end

    it "detects a Bundler trait" do
      @config = Warbler::Config.new
      @config.traits.should include(Warbler::Traits::Bundler)
    end

    it "detects a Bundler Gemfile and process only its gems" do
      @war.apply(conf = Warbler::Config.new {|c| c.gems << "rake"})
      file_list(%r{WEB-INF/Gemfile}).should_not be_empty
      file_list(%r{WEB-INF/gems/specifications/rspec}).should_not be_empty
      file_list(%r{WEB-INF/gems/specifications/rake}).should be_empty
    end

    it "copies Bundler gemfiles into the war" do
      File.open("Gemfile.lock", "w") {|f| f << "GEM"}
      @war.apply(Warbler::Config.new)
      file_list(%r{WEB-INF/Gemfile}).should_not be_empty
      file_list(%r{WEB-INF/Gemfile.lock}).should_not be_empty
    end

    it "allows overriding of the gem path when using Bundler" do
      @war.apply(Warbler::Config.new {|c| c.gem_path = '/WEB-INF/jewels' })
      file_list(%r{WEB-INF/jewels/specifications/rspec}).should_not be_empty
    end

    it "works with :git entries in Bundler Gemfiles" do
      File.open("Gemfile", "w") {|f| f << "gem 'warbler', :git => '#{Warbler::WARBLER_HOME}'\n"}
      silence { ruby "-S", "bundle", "install", "--local" }
      @war.apply(Warbler::Config.new)
      file_list(%r{WEB-INF/gems/gems/warbler[^/]*/lib/warbler/version\.rb}).should_not be_empty
      file_list(%r{WEB-INF/gems/specifications/warbler}).should_not be_empty
    end

    it "does not bundle dependencies in the test group by default" do
      File.open("Gemfile", "w") {|f| f << "gem 'rake'\ngroup :test do\ngem 'rspec'\nend\n"}
      @war.apply(Warbler::Config.new)
      file_list(%r{WEB-INF/gems/gems/rake[^/]*/}).should_not be_empty
      file_list(%r{WEB-INF/gems/gems/rspec[^/]*/}).should be_empty
      file_list(%r{WEB-INF/gems/specifications/rake}).should_not be_empty
      file_list(%r{WEB-INF/gems/specifications/rspec}).should be_empty
    end

    it "adds BUNDLE_WITHOUT to init.rb" do
      @war.add_init_file(Warbler::Config.new)
      contents = @war.files['META-INF/init.rb'].read
      contents.should =~ /ENV\['BUNDLE_WITHOUT'\]/
      contents.should =~ /'development:test'/
    end
  end

  it "skips directories that don't exist in config.dirs and print a warning" do
    @config.dirs = %w(lib notexist)
    silence { @war.apply(@config) }
    file_list(%r{WEB-INF/lib}).should_not be_empty
    file_list(%r{WEB-INF/notexist}).should be_empty
  end

  it "excludes Warbler's old tmp/war directory by default" do
    mkdir_p "tmp/war"
    touch "tmp/war/index.html"
    @config = Warbler::Config.new
    @config.dirs += ["tmp"]
    @war.apply(@config)
    file_list(%r{WEB-INF/tmp/war/index\.html}).should be_empty
  end

  it "writes gems to location specified by gem_path" do
    @config = Warbler::Config.new do |c|
      c.gem_path = "/WEB-INF/jewels"
      c.gems << 'rake'
    end
    elements = expand_webxml
    file_list(%r{WEB-INF/jewels}).should_not be_empty
    elements.to_a(
      "context-param/param-name[text()='gem.path']"
      ).should_not be_empty
    elements.to_a(
      "context-param/param-name[text()='gem.path']/../param-value"
      ).first.text.should == "/WEB-INF/jewels"
  end

  it "allows adding additional WEB-INF files via config.webinf_files" do
    File.open("myserver-web.xml", "w") do |f|
      f << "<web-app></web-app>"
    end
    @war.apply(Warbler::Config.new {|c| c.webinf_files = FileList['myserver-web.xml'] })
    file_list(%r{WEB-INF/myserver-web.xml}).should_not be_empty
  end

  it "allows expanding of additional WEB-INF files via config.webinf_files" do
    File.open("myserver-web.xml.erb", "w") do |f|
      f << "<web-app><%= webxml.rails.env %></web-app>"
    end
    @war.apply(Warbler::Config.new {|c| c.webinf_files = FileList['myserver-web.xml.erb'] })
    file_list(%r{WEB-INF/myserver-web.xml}).should_not be_empty
    @war.files['WEB-INF/myserver-web.xml'].read.should =~ /web-app.*production/
  end

  it "excludes test files in gems according to config.gem_excludes" do
    @config.gem_excludes += [/^(test|spec)\//]
    @war.apply(@config)
    file_list(%r{WEB-INF/gems/gems/rake([^/]+)/test/test_rake.rb}).should be_empty
  end

  it "creates a META-INF/init.rb file with startup config" do
    @war.apply(@config)
    file_list(%r{META-INF/init.rb}).should_not be_empty
  end

  it "allows adjusting the init file location in the war" do
    @config.init_filename = 'WEB-INF/init.rb'
    @war.add_init_file(@config)
    file_list(%r{WEB-INF/init.rb}).should_not be_empty
  end

  it "allows adding custom files' contents to init.rb" do
    @config = Warbler::Config.new { |c| c.init_contents << "Rakefile" }
    @war.add_init_file(@config)
    contents = @war.files['META-INF/init.rb'].read
    contents.should =~ /require 'rake'/
  end

  it "does not have escaped HTML in WARBLER_CONFIG" do
    @config.webxml.dummy = '<dummy/>'
    @war.apply(@config)
    @war.files['META-INF/init.rb'].read.should =~ /<dummy\/>/
  end
end
