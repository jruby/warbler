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
    Dir.chdir("spec/sample")
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
                  "tmp/gems.jar", "file.txt", 'manifest', 'Gemfile']
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

  it "should be able to define all tasks successfully" do
    Warbler::Task.new "warble", @config
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
