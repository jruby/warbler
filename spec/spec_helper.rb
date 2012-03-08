#--
# Copyright (c) 2010-2011 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'rubygems'
require 'rspec'

$LOAD_PATH.unshift File.dirname(__FILE__) + '/../lib'
require 'warbler'

raise %{Error: detected running Warbler specs in a Rails app;
Warbler specs are destructive to application directories.} if File.directory?("app")

require 'rbconfig'
RUBY_EXE = File.join Config::CONFIG['bindir'], Config::CONFIG['ruby_install_name']

require 'stringio'

def silence(io = nil)
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
  io = StringIO.new
  silence(io, &block)
  io.string
end

module ExampleGroupHelpers
  
  def run_in_directory(dir)
    before :each do
      (@pwd ||= []) << Dir.getwd
      Dir.chdir(@pwd.first) # let directory always be relative to project root
      mkdir_p(dir, :verbose => false)
      Dir.chdir(dir)
    end

    after :each do
      Dir.chdir(@pwd.pop)
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
      (ENV.keys.grep(/BUNDLE/) + ["RUBYOPT"]).each {|k| @env_save[k] = ENV[k]; ENV.delete(k)}
    end

    after(:each) do
      @env_save.keys.each {|k| ENV[k] = @env_save[k]}
    end
  end

  def cleanup_temp_files
    after(:each) do
      rm_rf FileList["log", ".bundle", "tmp/war"]
      rm_f FileList["*.war", "*.foobar", "**/config.ru", "*web.xml*", "config/web.xml*", "config/warble.rb",
                    "file.txt", 'manifest', '*Gemfile*', 'MANIFEST.MF*', 'init.rb*', '**/*.class']
    end
  end

  def run_out_of_process_with_drb
    before :all do
      require 'drb'
      DRb.start_service
      @orig_dir = Dir.pwd
    end

    let(:drbclient) do
      drb
      DRbObject.new(nil, 'druby://127.0.0.1:7890').tap do |drbclient|
        ready = nil
        e = nil
        100.times { ((ready = drbclient.ready?) && break) rescue e = $!; sleep 0.5 }
        raise e unless ready
      end
    end

    let(:drb_helper_args) { ["-I#{Warbler::WARBLER_HOME}/lib", File.join(@orig_dir, 'spec/drb_helper.rb')] }

    if defined?(JRUBY_VERSION)
      let(:drb) do
        Thread.new do
          ruby *drb_helper_args
        end
      end
      after :each do
        drbclient.stop
        drb.join
      end
    else
      let(:drb) do
        require 'childprocess'
        ChildProcess.build(FileUtils::RUBY, *drb_helper_args).tap {|d| d.start }
      end
      after :each do
        drb.stop
      end
    end
  end
  
end

RSpec.configure do |config|
  config.include Warbler::RakeHelper
  config.extend Warbler::RakeHelper
  config.extend ExampleGroupHelpers

  class << ::Object
    public :remove_const
  end
  
  config.after :each do
    Object.remove_const("Rails") if defined?(Rails)
    rm_rf "vendor"
  end
  
end
