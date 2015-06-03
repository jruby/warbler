#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
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
RUBY_EXE = File.join RbConfig::CONFIG['bindir'], RbConfig::CONFIG['ruby_install_name']

require 'fileutils'
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

require 'drb'
require File.expand_path('drb_default_id_conv', File.dirname(__FILE__))

module ExampleGroupHelpers
  def run_in_directory(dir)
    before :each do
      (@pwd ||= []) << Dir.getwd
      Dir.chdir(@pwd.first) # let directory always be relative to project root
      FileUtils.mkdir_p(dir, :verbose => false)
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

  def cleanup_temp_files(*except_files)
    after(:each) do
      FileUtils.rm_rf FileList[*(["log", ".bundle", "tmp"] - except_files)]
      FileUtils.rm_f  FileList[*(["*.war", "*.foobar", "**/config.ru", "*web.xml*", "config/web.xml*",
                                 "config/warble.rb", "file.txt", 'manifest', '*Gemfile*', 'MANIFEST.MF*', 'init.rb*',
                                 '**/*.class'] - except_files)]
    end
  end

  def create_git_gem(gem_name)
    before do
      @gem_dir = Dir.mktmpdir("#{gem_name}-#{rand(100)}")
      cur_dir = Dir.pwd
      Dir.chdir(@gem_dir) do
        `git init`
        `git config user.email "warbler-test@null.com"`
        `git config user.name  "Warbler Test"`

        # create the gemspec and Gemfile
        File.open("Gemfile", "w") do |f|
          f << <<-RUBY
          source "http://rubygems.org/"
          gemspec
          RUBY
        end

        File.open("#{gem_name}.gemspec", "w") do |f|
          f << <<-RUBY
          # -*- encoding: utf-8 -*-
          Gem::Specification.new do |gem|
            gem.name = "#{gem_name}"
            gem.version = '1.0'
            gem.authors = ['John Doe']
            gem.summary = "Gem for testing"
            gem.platform = Gem::Platform::RUBY
            gem.files = `git ls-files`.split("\n")
            gem.add_runtime_dependency 'rake', [">= 10.4.2"]
          end
          RUBY
        end

        Dir.mkdir("lib")
        Dir.mkdir("lib/#{gem_name}")

        File.open("lib/#{gem_name}/version.rb", "w") do |f|
          f << <<-RUBY
          VERSION = "1.0"
          RUBY
        end

        # `bundle install --local`
        `git add .`
        `git commit -am "first commit"`
      end
      Dir.chdir(cur_dir)
    end

    after do
      FileUtils.remove_entry_secure @gem_dir
    end
  end

  def run_out_of_process_with_drb
    before :all do
      DRb.start_service
      @orig_dir = Dir.pwd
    end

    let(:drbclient) do
      drb
      DRbObject.new(nil, 'druby://127.0.0.1:7890').tap do |drbclient|
        ready, error = nil, nil
        300.times do # timeout 30 secs (300 * 0.1)
          begin
            break if ready = drbclient.ready?
          rescue DRb::DRbConnError => e
            error = e; sleep 0.1
          end
        end
        raise error unless ready
      end
    end

    let(:drb_helper_args) { ["-I#{Warbler::WARBLER_HOME}/lib", File.join(@orig_dir, 'spec/drb_helper.rb')] }

    if defined?(JRUBY_VERSION)
      require 'jruby'
      let(:drb) do
        version_arg = JRuby.runtime.is1_9 ? "--1.9" : "--1.8"
        drb_thread = Thread.new do
          ruby *([ version_arg ] + drb_helper_args)
        end
        drb_thread.run
        drb_thread
      end
      after :each do
        drbclient.stop
        drb.join
      end
    else
      require 'childprocess'
      let(:drb) do
        ChildProcess.build(FileUtils::RUBY, *drb_helper_args).tap {|d| d.start }
      end
      after :each do
        drb.stop
      end
    end
  end

  def use_test_webserver
    before :each do
      webserver = double('server').as_null_object
      webserver.stub(:main_class).and_return 'WarMain.class'
      webserver.stub(:add) do |jar|
        jar.files['WEB-INF/webserver.jar'] = StringIO.new
      end
      Warbler::WEB_SERVERS['test'] = webserver
    end
    after :each do
      Warbler::WEB_SERVERS.delete('test')
    end
  end
end

RSpec.configure do |config|
  config.include Warbler::RakeHelper
  config.extend ExampleGroupHelpers

  class << ::Object
    public :remove_const
  end

  config.after :each do
    Object.remove_const("Rails") if defined?(Rails)
    rm_rf "vendor"
  end
end
