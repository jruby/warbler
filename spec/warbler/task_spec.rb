#--
# (c) Copyright 2007 Nick Sieger <nicksieger@gmail.com>
# See the file LICENSES.txt included with the distribution for
# software license details.
#++

require File.dirname(__FILE__) + '/../spec_helper'

describe Warbler::Task do
  before(:each) do
    @rake = Rake::Application.new
    Rake.application = @rake
    @config = Warbler::Config.new do |config|
      config.staging_dir = "pkg/tmp/war"
      config.war_name = "warbler"
      config.gems = ["rake"]
      config.dirs = %w(bin generators lib)
      config.public_html = FileList["tasks/**/*"]
      config.webxml.pool.maxActive = 5
    end
    mkdir_p "public"
    touch "public/index.html"
  end

  after(:each) do
    rm_rf "public"
  end

  def define_tasks(*tasks)
    options = tasks.last.kind_of?(Hash) ? tasks.pop : {}
    @defined_tasks ||= []
    tasks.each do |task|
      unless @defined_tasks.include?(task)
        Warbler::Task.new "warble", @config, "define_#{task}_task".to_sym do |t|
          options.each {|k,v| t.send "#{k}=", v }
        end
        @defined_tasks << task
      end
    end
  end

  def file_list(regex)
    FileList["#{@config.staging_dir}/**/*"].select {|f| f =~ regex }
  end

  after(:each) do
    define_tasks "clean"
    Rake::Task["warble:clean"].invoke
    rm_rf "config"
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
    file_list(%r{index\.html}).should_not be_nil
    file_list(%r{tasks/warbler\.rake}).should_not be_nil
  end

  it "should define a gems task for unpacking gems" do
    define_tasks "gems"
    Rake::Task["warble:gems"].invoke
    file_list(%r{WEB-INF/gems/gems/rake.*/lib/rake.rb}).should_not be_empty
    file_list(%r{WEB-INF/gems/specifications/rake.*\.gemspec}).should_not be_empty
  end

  it "should define a webxml task for creating web.xml" do
    define_tasks "webxml"
    Rake::Task["warble:webxml"].invoke
    file_list(%r{WEB-INF/web.xml$}).should_not be_empty
    require 'rexml/document'
    
    elements = File.open("#{@config.staging_dir}/WEB-INF/web.xml") do |f|
      REXML::Document.new(f).root.elements
    end
    elements.to_a(
      "context-param/param-name[text()='jruby.pool.maxActive']"
      ).should_not be_empty
    elements.to_a(
      "context-param/param-name[text()='jruby.pool.maxActive']/../param-value"
      ).first.text.should == "5"
  end

  it "should define a java_libs task for copying java libraries" do
    define_tasks "java_libs"
    Rake::Task["warble:java_libs"].invoke
    file_list(%r{WEB-INF/lib/jruby-complete.*\.jar$}).should_not be_empty
  end

  it "should define an app task for copying application files" do
    gems_ran = false
    task "warble:gems" do
      gems_ran = true
    end
    define_tasks "app"
    Rake::Task["warble:app"].invoke
    file_list(%r{WEB-INF/bin/warble$}).should_not be_empty
    file_list(%r{WEB-INF/generators/warble/warble_generator\.rb$}).should_not be_empty
    file_list(%r{WEB-INF/lib/warbler\.rb$}).should_not be_empty
    gems_ran.should == true
  end

  it "should define a jar task for creating the .war" do
    define_tasks "jar"
    mkdir_p @config.staging_dir
    touch "#{@config.staging_dir}/file.txt"
    Rake::Task["warble:jar"].invoke
    File.exist?("warbler.war").should == true
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
    @config.dirs << "spec"
    @config.excludes += FileList['spec/spec_helper.rb']
    task "warble:gems" do; end
    define_tasks "app"
    Rake::Task["warble:app"].invoke
    file_list(%r{spec/spec_helper.rb}).should be_empty
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

  it "should define a java_classes task for copying loose java classes" do
    @config.java_classes = FileList["Rakefile"]
    define_tasks "java_classes"
    Rake::Task["warble:java_classes"].invoke
    file_list(%r{WEB-INF/classes/Rakefile$}).should_not be_empty
  end
end

describe "The warbler.rake file" do
  it "should be able to list its contents" do
    output = `#{FileUtils::RUBY} -S rake -f #{Warbler::WARBLER_HOME}/tasks/warbler.rake -T`
    output.should =~ /war\s/
    output.should =~ /war:app/
    output.should =~ /war:clean/
    output.should =~ /war:gems/
    output.should =~ /war:jar/
    output.should =~ /war:java_libs/
    output.should =~ /war:java_classes/
    output.should =~ /war:public/
  end
end