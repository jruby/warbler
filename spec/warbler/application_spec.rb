#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.expand_path('../../spec_helper', __FILE__)

describe Warbler::Application do
  run_in_directory "spec/sample_war"

  before :each do
    verbose(false)
    @argv = ARGV.dup
    ARGV.clear
    @app = Rake.application
    rm_f "config/warble.rb"
    @detection = Warbler.framework_detection
    Warbler.framework_detection = false
  end

  after :each do
    Rake.application = @app
    Warbler.project_application = nil
    Warbler.application = nil
    Warbler.framework_detection = @detection
    @argv.reverse.each {|a| ARGV.unshift a}
    rm_rf FileList['lib/tasks/warbler']
  end

  it "should be able to list its tasks" do
    ARGV.unshift "-T"
    output = capture do
      Warbler::Application.new.run
    end
    expect(output).to match /warble war\s/
    expect(output).to match /warble war:clean/
    expect(output).to match /warble war:debug/
  end

  it "should display the version" do
    ARGV.unshift "version"
    expect(capture { Warbler::Application.new.run }).to match /#{Warbler::VERSION}/
  end

  it "should copy a fresh config file into place" do
    expect(File.exist?("config/warble.rb")).to_not be true
    ARGV.unshift "config"
    silence { Warbler::Application.new.run }
    expect(File.exist?("config/warble.rb")).to be true
  end

  it "should refuse to copy over an existing config file" do
    touch "config/warble.rb"
    ARGV.unshift "config"
    expect(capture { Warbler::Application.new.run }).to match /already exists/
  end

  it "should complain if the config directory is missing" do
    begin
      mv "config", "config-tmp"
      ARGV.unshift "config"
      expect(capture { Warbler::Application.new.run }).to match /missing/
    ensure
      mv "config-tmp", "config"
    end
  end

  it "should refuse to pluginize if the lib/tasks/warbler directory exists" do
    mkdir_p "lib/tasks/warbler"
    ARGV.unshift "pluginize"
    silence { Warbler::Application.new.run }
    expect(File.exist?("lib/tasks/warbler/warbler.rake")).to_not be true
  end

  it "should define a pluginize task for adding the tasks to a Rails application" do
    ARGV.unshift "pluginize"
    silence { Warbler::Application.new.run }
    expect(File.exist?("lib/tasks/warbler/warbler.rake")).to be true
  end

  it "should provide a means to load the project Rakefile" do
    silence { Warbler::Application.new.load_project_rakefile }
  end
end

describe Warbler::Application do
  it "should report Warbler version with --version" do
    output = `#{RUBY_EXE} -Ilib -S bin/warble --version`
    expect(output).to match /warbler/i
    expect(output).to match /#{Warbler::VERSION}/
  end
end
