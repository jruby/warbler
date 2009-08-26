#--
# (c) Copyright 2007-2009 Sun Microsystems, Inc.
# See the file LICENSES.txt included with the distribution for
# software license details.
#++

require File.dirname(__FILE__) + '/../spec_helper'

describe Warbler::Task do
  before(:each) do
    @rake = Rake::Application.new
    Rake.application = @rake
    verbose(false)
    @pwd = Dir.getwd
    Dir.chdir("spec/sample")
    mkdir_p "log"
    touch "log/test.log"
    @config = Warbler::Config.new do |config|
      config.staging_dir = "tmp/war"
      config.war_name = "warbler"
      config.gems = ["rake"]
      config.webxml.jruby.max.runtimes = 5
    end
  end

  after(:each) do
    define_tasks "clean"
    Rake::Task["warble:clean"].invoke
    rm_rf "log"
    rm_f FileList["config.ru", "*web.xml", "config/web.xml*", "config/warble.rb"]
    Dir.chdir(@pwd)
  end

  def define_tasks(*tasks)
    options = tasks.last.kind_of?(Hash) ? tasks.pop : {}
    @defined_tasks ||= []
    tasks.each do |task|
      unless @defined_tasks.include?(task)
        meth = "define_#{task}_task"
        meth = "define_#{task}_tasks" unless Warbler::Task.private_instance_methods.include?(meth)
        Warbler::Task.new "warble", @config, meth.to_sym do |t|
          options.each {|k,v| t.send "#{k}=", v }
        end
        @defined_tasks << task
      end
    end
  end

  def file_list(regex)
    FileList["#{@config.staging_dir}/**/*"].select {|f| f =~ regex }
  end

  it "should define a clean task for removing the staging directory" do
    define_tasks "clean"
    mkdir_p @config.staging_dir
    Rake::Task["warble:clean"].invoke
    File.exist?(@config.staging_dir).should == false
  end

  it "should define a public task for copying the public files" do
    define_tasks "public"
    Rake::Task["warble:public"].invoke
    file_list(%r{^#{@config.staging_dir}/index\.html}).should_not be_empty
  end

  it "should define a gems task for unpacking gems" do
    @config.gems << "rails"
    define_tasks "gems"
    Rake::Task["warble:gems"].invoke
    file_list(%r{WEB-INF/gems/gems/rake.*/lib/rake.rb}).should_not be_empty
    file_list(%r{WEB-INF/gems/specifications/rake.*\.gemspec}).should_not be_empty
  end

  it "should define a app task for copying application files" do
    define_tasks "app", "gems"
    Rake::Task["warble:app"].invoke
    file_list(%r{WEB-INF/log}).should_not be_empty
    file_list(%r{WEB-INF/log/*.log}).should be_empty
  end

  def expand_webxml
    define_tasks "webxml"
    Rake::Task["warble:webxml"].invoke
    require 'rexml/document'
    File.open("#{@config.staging_dir}/WEB-INF/web.xml") do |f|
      REXML::Document.new(f).root.elements
    end
  end

  it "should define a webxml task for creating web.xml" do
    elements = expand_webxml
    elements.to_a(
      "context-param/param-name[text()='jruby.max.runtimes']"
      ).should_not be_empty
    elements.to_a(
      "context-param/param-name[text()='jruby.max.runtimes']/../param-value"
      ).first.text.should == "5"
  end

  it "should include custom context parameters" do
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
    define_tasks "webxml"
    mkdir_p "config"
    File.open("config/web.xml", "w") {|f| f << "Hi there" }
    Rake::Task["warble:webxml"].invoke
    files = file_list(%r{WEB-INF/web.xml$})
    files.should_not be_empty
    File.open(files.first) {|f| f.read}.should == "Hi there"
  end

  it "should use a config/web.xml.erb if it exists" do
    define_tasks "webxml"
    mkdir_p "config"
    File.open("config/web.xml.erb", "w") {|f| f << "Hi <%= webxml.public.root %>" }
    Rake::Task["warble:webxml"].invoke
    files = file_list(%r{WEB-INF/web.xml$})
    files.should_not be_empty
    File.open(files.first) {|f| f.read}.should == "Hi /"
  end

  it "should define a java_libs task for copying java libraries" do
    define_tasks "java_libs"
    Rake::Task["warble:java_libs"].invoke
    file_list(%r{WEB-INF/lib/jruby-.*\.jar$}).should_not be_empty
  end

  it "should define an app task for copying application files" do
    gems_ran = false
    task "warble:gems" do
      gems_ran = true
    end
    define_tasks "app"
    Rake::Task["warble:app"].invoke
    file_list(%r{WEB-INF/app$}).should_not be_empty
    file_list(%r{WEB-INF/config$}).should_not be_empty
    file_list(%r{WEB-INF/lib$}).should_not be_empty
    gems_ran.should == true
  end

  it "should define a jar task for creating the .war" do
    define_tasks "jar"
    mkdir_p @config.staging_dir
    touch "#{@config.staging_dir}/file.txt"
    Rake::Task["warble:jar"].invoke
    File.exist?("warbler.war").should == true
  end

  it "should define an exploded task for creating an exploded Rails app" do
    @config.java_classes = ["Rakefile"]
    @config.java_libs = []
    define_tasks "webxml", "exploded", "java_classes", "gems"
    Rake::Task['warble:exploded'].invoke
    File.exist?("web.xml").should == true
    File.exist?("sun-web.xml").should == true
    File.symlink?("gems").should == true
    File.symlink?("public/WEB-INF").should == true
    Rake::Task['warble:clean:exploded'].invoke
  end

  it "should accept an autodeploy directory where the war should be created" do
    define_tasks "jar"
    require 'tempfile'
    @config.autodeploy_dir = Dir::tmpdir
    mkdir_p @config.staging_dir
    touch "#{@config.staging_dir}/file.txt"
    Rake::Task["warble:jar"].invoke
    File.exist?(File.join("#{Dir::tmpdir}","warbler.war")).should == true
  end

  it "should define a war task for bundling up everything" do
    app_ran = false; task "warble:app" do; app_ran = true; end
    public_ran = false; task "warble:public" do; public_ran = true; end
    jar_ran = false; task "warble:jar" do; jar_ran = true; end
    webxml_ran = false; task "warble:webxml" do; webxml_ran = true; end
    define_tasks "main"
    Rake::Task["warble"].invoke
    app_ran.should == true
    public_ran.should == true
    jar_ran.should == true
    webxml_ran.should == true
  end

  it "should be able to exclude files from the .war" do
    @config.excludes += FileList['lib/tasks/utils.rake']
    task "warble:gems" do; end
    define_tasks "app"
    Rake::Task["warble:app"].invoke
    file_list(%r{lib/tasks/utils.rake}).should be_empty
  end

  it "should be able to define all tasks successfully" do
    Warbler::Task.new "warble", @config
  end

  it "should read configuration from #{Warbler::Config::FILE}" do
    mkdir_p "config"
    File.open(Warbler::Config::FILE, "w") do |dest|
      contents = 
        File.open("#{Warbler::WARBLER_HOME}/generators/warble/templates/warble.rb") do |src|
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
    }.should raise_error
  end

  it "should handle platform-specific gems" do
    spec = mock "gem spec"
    spec.stub!(:name).and_return "hpricot"
    spec.stub!(:version).and_return "0.6.157"
    spec.stub!(:platform).and_return "java"
    spec.stub!(:original_platform).and_return "java"
    spec.stub!(:loaded_from).and_return "hpricot.gemspec"
    spec.stub!(:dependencies).and_return []
    Gem.source_index.should_receive(:search).and_return do |gem|
      gem.name.should == "hpricot"
      [spec]
    end
    File.should_receive(:exist?).with(File.join(Gem.dir, 'cache', "hpricot-0.6.157-java.gem")).and_return true
    @config.gems = ["hpricot"]
    define_tasks "gems"
  end

  it "should allow specification of dependency by Gem::Dependency" do
    spec = mock "gem spec"
    spec.stub!(:name).and_return "hpricot"
    spec.stub!(:version).and_return "0.6.157"
    spec.stub!(:platform).and_return "java"
    spec.stub!(:original_platform).and_return "java"
    spec.stub!(:loaded_from).and_return "hpricot.gemspec"
    spec.stub!(:dependencies).and_return []
    Gem.source_index.should_receive(:search).and_return do |gem|
      gem.name.should == "hpricot"
      [spec]
    end
    File.should_receive(:exist?).with(File.join(Gem.dir, 'cache', "hpricot-0.6.157-java.gem")).and_return true
    @config.gems = [Gem::Dependency.new("hpricot", "> 0.6")]
    define_tasks "gems"
  end

  it "should define a java_classes task for copying loose java classes" do
    @config.java_classes = FileList["Rakefile"]
    define_tasks "java_classes"
    Rake::Task["warble:java_classes"].invoke
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
    Object.const_set("Merb", merb)
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
    @config = Warbler::Config.new
    define_tasks "copy_gems"
    Rake.application.lookup("gem:rake-#{RAKEVERSION}").should be_nil
  end

  it "should warn about using Merb < 1.0" do
    task :merb_env do
      Object.const_set("Merb", Module.new)
    end
    @config = Warbler::Config.new
    @config.webxml.booter.should == :merb
  end

  it "should set the jruby max runtimes to 1 when MT Rails is detected" do
    task :environment do
      rails = mock_rails_module
      config = mock "config"
      rails.stub!(:configuration).and_return(config)
      config.stub!(:threadsafe!)
    end
    @config = Warbler::Config.new
    @config.webxml.booter.should == :rails
    @config.webxml.jruby.max.runtimes.should == 1
  end

  it "should skip directories that don't exist in config.dirs and print a warning" do
    @config = Warbler::Config.new
    @config.dirs = %w(lib notexist)
    define_tasks "webinf_file"
    Rake.application.lookup("#{@config.staging_dir}/WEB-INF/lib").should_not be_nil
    Rake.application.lookup("#{@config.staging_dir}/WEB-INF/notexist").should be_nil
  end
end

describe "The warbler.rake file" do
  it "should be able to list its contents" do
    output = `#{FileUtils::RUBY} -S rake -f #{Warbler::WARBLER_HOME}/tasks/warbler.rake -T`
    output.should =~ /war\s/
    output.should =~ /war:exploded/
    output.should =~ /war:app/
    output.should =~ /war:clean/
    output.should =~ /war:gems/
    output.should =~ /war:jar/
    output.should =~ /war:java_libs/
    output.should =~ /war:java_classes/
    output.should =~ /war:public/
  end
end

describe "Debug targets" do
  before(:each) do
    @rake = Rake::Application.new
    Rake.application = @rake
    verbose(false)
    silence { Warbler::Task.new :war, Object.new }
  end

  it "should print out lists of files" do
    capture { Rake::Task["war:debug:public"].invoke }.should =~ /public/
    capture { Rake::Task["war:debug:gems"].invoke }.should =~ /gems/
    capture { Rake::Task["war:debug:java_libs"].invoke }.should =~ /java_libs/
    capture { Rake::Task["war:debug:java_classes"].invoke }.should =~ /java_classes/
    capture { Rake::Task["war:debug:app"].invoke }.should =~ /app/
    capture { Rake::Task["war:debug:includes"].invoke }.should =~ /include/
    capture { Rake::Task["war:debug:excludes"].invoke }.should =~ /exclude/
    capture { Rake::Task["war:debug"].invoke }.should =~ /Config/
  end
end
