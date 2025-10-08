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
CLEAN << "pkg" << "doc" << Dir['integration/**/target']

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = ['--color', "--format documentation"]
end

task :default => :spec

# use Mavenfile to define :jar task
require 'maven/ruby/maven'
mvn = Maven::Ruby::Maven.new
mvn << "-Djruby.version=#{JRUBY_VERSION}"
mvn << "-Dbundler.version=#{Bundler::VERSION}"
mvn << '--no-transfer-progress'

if defined?(JRUBY_VERSION) && !JRUBY_VERSION.start_with?('9.0')
  mvn.inherit_jruby_version
end

desc 'compile java sources and build jar'
task :jar do
  success = mvn.prepare_package
  exit(1) unless success
end

desc 'run some integration test'
task :integration do
  success = mvn.verify
  exit(1) unless success
end

desc 'generate the pom.xml from the Mavenfile'
task :pom do
  success = mvn.validate('-Dpolyglot.dump.pom=pom.xml')
  exit(1) unless success
end

# Make sure jar gets compiled before the gem is built
task :build => :jar

require 'rdoc/task'
RDoc::Task.new(:docs) do |rd|
  gemspec = Gem::Specification.load(File.expand_path('warbler.gemspec', File.dirname(__FILE__)))
  rd.rdoc_dir = "doc"
  rd.rdoc_files.include("README.rdoc", "History.txt", "LICENSE.txt")
  rd.rdoc_files += gemspec.require_paths
  rd.options << '--title' << "#{gemspec.name}-#{gemspec.version} Documentation"
  rd.options += gemspec.rdoc_options
end

task :release => :docs
