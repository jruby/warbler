#-*- mode: ruby -*-
#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'bundler/gem_helper'
Bundler::GemHelper.install_tasks :dir => File.dirname(__FILE__)

require 'rake/clean'
CLEAN << "pkg" << "doc" << Dir['**/target'] << "lib/warbler_jar.jar"

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = ['--force-color', "--format documentation"]
end

task :spec => :jar

task :default => :spec

# drive the java build (pom.xml) with regular maven
require File.expand_path('lib/warbler/version', File.dirname(__FILE__))

def mvn(*goals)
  args = %W[mvn -B --no-transfer-progress -Dstyle.color=always
            -Drevision=#{Warbler::VERSION} -Djruby.version=#{JRUBY_VERSION}]
  args << "-Djruby-rack.version=#{ENV['JRUBY_RACK_VERSION']}" if ENV['JRUBY_RACK_VERSION']
  # scrub the outer bundler env (RUBYOPT/BUNDLE_*) so JRuby subprocesses inside the
  # maven build don't try to load this project's Gemfile
  Bundler.with_unbundled_env { sh(*args, *goals) }
end

desc 'compile java sources and build jar'
task :jar do
  mvn 'prepare-package'
end

desc 'run some integration test'
task :integration => :build do
  mvn 'verify'
end

# Make sure jar gets compiled before the gem is built
task :build => :jar

require 'rdoc/task'
RDoc::Task.new(:docs) do |rd|
  gemspec = Gem::Specification.load(File.expand_path('warbler.gemspec', File.dirname(__FILE__)))
  rd.rdoc_dir = "doc"
  rd.rdoc_files.include("README.rdoc", "CHANGELOG.md", "LICENSE.txt")
  rd.rdoc_files += gemspec.require_paths
  rd.options << '--title' << "#{gemspec.name}-#{gemspec.version} Documentation"
  rd.options += gemspec.rdoc_options
end

task :release => :docs
