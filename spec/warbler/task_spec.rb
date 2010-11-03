#--
# Copyright (c) 2010 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.dirname(__FILE__) + '/../spec_helper'

describe Warbler::Task do
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
    end
    @task = Warbler::Task.new "warble", @config
  end

  after(:each) do
    Rake::Task["warble:clean"].invoke
    rm_rf "log"
    rm_f FileList["config.ru", "*web.xml", "config/web.xml*", "config/warble.rb",
                  "config/special.txt", "config/link.txt", "tmp/gems.jar",
                  "file.txt", 'Gemfile', 'lib/rakelib', '**/*.class']
    Dir.chdir(@pwd)
  end

  it "should define a clean task for removing the war file" do
    war_file = "#{@config.war_name}.war"
    touch war_file
    Rake::Task["warble:clean"].invoke
    File.exist?(war_file).should == false
  end

  it "should define a make_gemjar task for storing gems in a jar file" do
    silence { Rake::Task["warble:make_gemjar"].invoke }
    File.exist?("tmp/gems.jar").should == true
    @task.war.files.keys.should_not include(%r{WEB-INF\/gems})
    @task.war.files.keys.should include("WEB-INF/lib/gems.jar")
  end

  it "should define a war task for bundling up everything" do
    files_ran = false; task "warble:files" do; files_ran = true; end
    jar_ran = false; task "warble:jar" do; jar_ran = true; end
    silence { Rake::Task["warble"].invoke }
    files_ran.should == true
    jar_ran.should == true
  end

  it "should define a jar task for creating the .war" do
    touch "file.txt"
    @task.war.files["file.txt"] = "file.txt"
    silence { Rake::Task["warble:jar"].invoke }
    File.exist?("#{@config.war_name}.war").should == true
  end

  it "should invoke feature tasks configured in config.features" do
    @config.features << "gemjar"
    silence { Rake::Task["warble"].invoke }
    @task.war.files.keys.should include("WEB-INF/lib/gems.jar")
  end

  it "should warn and skip unknown features configured in config.features" do
    @config.features << "bogus"
    capture { Rake::Task["warble"].invoke }.should =~ /unknown feature `bogus'/
  end

  it "should define an executable task for embedding a server in the war file" do
    silence { Rake::Task["warble:executable"].invoke }
    @task.war.files.keys.should include('WEB-INF/winstone.jar')
  end

  it "should be able to define all tasks successfully" do
    Warbler::Task.new "warble", @config
  end

  it "should compile any ruby files specified" do
    @config.features << "compiled"
    silence { Rake::Task["warble"].invoke }

    java_class_magic_number = [0xCA,0xFE,0xBA,0xBE].map { |magic_char| magic_char.chr }.join

    Zip::ZipFile.open("#{@config.war_name}.war") do |zf|
      java_class_header     = zf.get_input_stream('WEB-INF/app/helpers/application_helper.class') {|io| io.read }[0..3]
      ruby_class_definition = zf.get_input_stream('WEB-INF/app/helpers/application_helper.rb') {|io| io.read }

      java_class_header.should == java_class_magic_number
      ruby_class_definition.should == %{require __FILE__.sub(/.rb$/, '.class')}
    end
  end

  it "should process symlinks by storing a file in the archive that has the same contents as the source" do
    File.open("config/special.txt", "wb") {|f| f << "special"}
    Dir.chdir("config") { ln_s "special.txt", "link.txt" }
    silence { Rake::Task["warble"].invoke }
    Zip::ZipFile.open("#{@config.war_name}.war") do |zf|
      special = zf.get_input_stream('WEB-INF/config/special.txt') {|io| io.read }
      link = zf.get_input_stream('WEB-INF/config/link.txt') {|io| io.read }
      link.should == special
    end
  end

  it "should process directory symlinks by copying the whole subdirectory" do
    Dir.chdir("lib") { ln_s "tasks", "rakelib" }
    silence { Rake::Task["warble"].invoke }
    Zip::ZipFile.open("#{@config.war_name}.war") do |zf|
      zf.find_entry("WEB-INF/lib/tasks/utils.rake").should_not be_nil
      zf.find_entry("WEB-INF/lib/rakelib/").should_not be_nil
      zf.find_entry("WEB-INF/lib/rakelib/utils.rake").should_not be_nil if defined?(JRUBY_VERSION)
    end
  end

  it "should use a Bundler Gemfile to include gems" do
    File.open("Gemfile", "w") {|f| f << "gem 'rspec'"}
    @config.bundler = true
    @config.send(:detect_bundler_gems)
    silence { Rake::Task["warble"].invoke }
    Zip::ZipFile.open("#{@config.war_name}.war") do |zf|
      rspec_version = @config.gems.keys.detect {|k| k.name == 'rspec'}.version
      zf.find_entry("WEB-INF/gems/specifications/rspec-#{rspec_version}.gemspec").should_not be_nil
    end
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
    capture { Rake::Task["war:debug:includes"].invoke }.should =~ /include/
    capture { Rake::Task["war:debug:excludes"].invoke }.should =~ /exclude/
    capture { Rake::Task["war:debug"].invoke }.should =~ /Config/
  end
end
