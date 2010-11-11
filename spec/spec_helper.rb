#--
# Copyright (c) 2010 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'rubygems'
require 'spec'

$LOAD_PATH.unshift File.dirname(__FILE__) + '/../lib'
require 'warbler'

raise %{Error: detected running Warbler specs in a Rails app;
Warbler specs are destructive to application directories.} if File.directory?("app")

def silence(io = nil)
  require 'stringio'
  old_stdout = $stdout
  old_stderr = $stderr
  $stdout = io || StringIO.new
  $stderr = io || StringIO.new
  yield
ensure
  $stdout = old_stdout
  $stderr = old_stderr
end

def capture(&block)
  require 'stringio'
  io = StringIO.new
  silence(io, &block)
  io.string
end

module Spec::Example::ExampleGroupMethods
  def run_in_directory(dir)
    before :each do
      @pwd = Dir.getwd
      Dir.chdir(dir)
    end

    after :each do
      Dir.chdir(@pwd)
    end
  end

  def use_fresh_rake_application
    before :each do
      @rake = Rake::Application.new
      Rake.application = @rake
      verbose(false)
    end
  end

  def use_fresh_environment
    before(:each) do
      @env_save = {}
      (ENV.keys.grep(/BUNDLE/) + ["RUBYOPT", "GEM_PATH"]).each {|k| @env_save[k] = ENV[k]; ENV[k] = nil}
    end

    after(:each) do
      @env_save.keys.each {|k| ENV[k] = @env_save[k]}
    end
  end

  def cleanup_temp_files
    after(:each) do
      rm_rf FileList["log", ".bundle", "tmp/war"]
      rm_f FileList["*.war", "*.foobar", "**/config.ru", "*web.xml*", "config/web.xml*", "config/warble.rb",
                    "file.txt", 'manifest', 'Gemfile*', 'MANIFEST.MF*', 'init.rb*', '**/*.class']
    end
  end
end

Spec::Runner.configure do |config|
  config.after(:each) do
    class << Object
      public :remove_const
    end
    Object.remove_const("Rails") rescue nil
    rm_rf "vendor"
  end
end
