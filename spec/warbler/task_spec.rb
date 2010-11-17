#--
# Copyright (c) 2010 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.dirname(__FILE__) + '/../spec_helper'

describe Warbler::Task do
  run_in_directory "spec/sample_war"

  let :config do
    Warbler::Config.new do |config|
      config.jar_name = "warbler"
      config.gems = ["rake"]
      config.webxml.jruby.max.runtimes = 5
    end
  end

  let(:warble_task) { Warbler::Task.new "warble", config }

  def run_task(t)
    warble_task
    Rake::Task[t].invoke
  end

  before :each do
    @rake = Rake::Application.new
    Rake.application = @rake
    verbose(false)
    mkdir_p "log"
    touch "log/test.log"
  end

  after :each do
    run_task "warble:clean"
    rm_rf "log"
    rm_f FileList["config.ru", "*web.xml", "config/web.xml*", "config/warble.rb",
                  "config/special.txt", "config/link.txt", "tmp/gems.jar",
                  "file.txt", 'Gemfile', 'lib/rakelib', '**/*.class']
  end

  it "should define a clean task for removing the war file" do
    war_file = "#{config.jar_name}.war"
    touch war_file

    run_task "warble:clean"
    File.exist?(war_file).should == false
  end

  it "should define a make_gemjar task for storing gems in a jar file" do
    silence { run_task "warble:gemjar"; run_task "warble:files" }
    File.exist?("tmp/gems.jar").should == true
    warble_task.jar.files.keys.should_not include(%r{WEB-INF\/gems})
    warble_task.jar.files.keys.should include("WEB-INF/lib/gems.jar")
  end

  it "should define a war task for bundling up everything" do
    files_ran = false; task "warble:files" do; files_ran = true; end
    jar_ran = false; task "warble:jar" do; jar_ran = true; end
    silence { run_task "warble" }
    files_ran.should == true
    jar_ran.should == true
  end

  it "should define a jar task for creating the .war" do
    touch "file.txt"
    warble_task.jar.files["file.txt"] = "file.txt"
    silence { run_task "warble:jar" }
    File.exist?("#{config.jar_name}.war").should == true
  end

  it "should invoke feature tasks configured in config.features" do
    config.features << "gemjar"
    silence { run_task "warble" }
    warble_task.jar.files.keys.should include("WEB-INF/lib/gems.jar")
  end

  it "should warn and skip unknown features configured in config.features" do
    config.features << "bogus"
    capture { run_task "warble" }.should =~ /unknown feature `bogus'/
  end

  it "should define an executable task for embedding a server in the war file" do
    silence { run_task "warble:executable"; run_task "warble:files" }
    warble_task.jar.files.keys.should include('WEB-INF/winstone.jar')
  end

  it "should be able to define all tasks successfully" do
    Warbler::Task.new "warble", config
  end

  it "should compile any ruby files specified" do
    ruby_file_path         = 'app/helpers/application_helper.rb'
    escaped_ruby_file_path = 'app/helpers/application_helper\.rb'
    java_file_path         = 'app/helpers/application_helper.class'

    config.features << "compiled"
    silence { run_task "warble" }

    Zip::ZipFile.open("#{config.jar_name}.war") do |zf|
      java_class_header     = zf.get_input_stream("WEB-INF/#{java_file_path}") {|io| io.read }[0..3]
      ruby_class_definition = zf.get_input_stream("WEB-INF/#{ruby_file_path}") {|io| io.read }

      java_class_header.should == Warbler::Jar::JAVA_CLASS_MAGIC_NUMBER
      ruby_class_definition.should == %{require __FILE__.sub(%r{#{escaped_ruby_file_path}$},'#{java_file_path}')}
    end
  end

  it "should correctly compile any ruby files with dots in their names" do
    ruby_file_path         = 'lib/with.dot.rb'
    escaped_ruby_file_path = 'lib/with\.dot\.rb'
    java_file_path         = 'lib/with_dot_dot.class'

    #
    # jrubyc transforms files like foo-bar.rb to foo_minus_bar.class
    # and directories like lib/some-library/foo.rb to lib/some_minus_library/foo.class
    #
    config.features << "compiled"
    config.compiled_ruby_files = FileList["lib/*.rb"]
    silence { run_task "warble" }

    Zip::ZipFile.open("#{config.jar_name}.war") do |zf|
      java_class_header     = zf.get_input_stream("WEB-INF/#{java_file_path}") {|io| io.read }[0..3]
      ruby_class_definition = zf.get_input_stream("WEB-INF/#{ruby_file_path}") {|io| io.read }

      java_class_header.should == Warbler::Jar::JAVA_CLASS_MAGIC_NUMBER
      ruby_class_definition.should == %{require __FILE__.sub(%r{#{escaped_ruby_file_path}$},'#{java_file_path}')}
    end
  end

  it "should delete .class files after finishing the jar" do
    config.features << "compiled"
    silence { run_task "warble" }
    File.exist?('app/helpers/application_helper.class').should be_false
  end

  it "should process symlinks by storing a file in the archive that has the same contents as the source" do
    File.open("config/special.txt", "wb") {|f| f << "special"}
    Dir.chdir("config") { ln_s "special.txt", "link.txt" }
    silence { run_task "warble" }
    Zip::ZipFile.open("#{config.jar_name}.war") do |zf|
      special = zf.get_input_stream('WEB-INF/config/special.txt') {|io| io.read }
      link = zf.get_input_stream('WEB-INF/config/link.txt') {|io| io.read }
      link.should == special
    end
  end

  it "should process directory symlinks by copying the whole subdirectory" do
    Dir.chdir("lib") { ln_s "tasks", "rakelib" }
    silence { run_task "warble" }
    Zip::ZipFile.open("#{config.jar_name}.war") do |zf|
      zf.find_entry("WEB-INF/lib/tasks/utils.rake").should_not be_nil
      zf.find_entry("WEB-INF/lib/rakelib/").should_not be_nil
      zf.find_entry("WEB-INF/lib/rakelib/utils.rake").should_not be_nil if defined?(JRUBY_VERSION)
    end
  end

  it "should use a Bundler Gemfile to include gems" do
    File.open("Gemfile", "w") {|f| f << "gem 'rspec'"}
    silence { run_task "warble" }
    Zip::ZipFile.open("#{config.jar_name}.war") do |zf|
      rspec_version = config.gems.keys.detect {|k| k.name == 'rspec'}.version
      zf.find_entry("WEB-INF/gems/specifications/rspec-#{rspec_version}.gemspec").should_not be_nil
    end
  end
end

describe "Debug targets" do
  run_in_directory "spec/sample_war"

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
