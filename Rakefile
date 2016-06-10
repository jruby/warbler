#-*- mode: ruby -*-
#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

begin
  require 'bundler'
rescue LoadError
  warn "\nPlease `gem install bundler' and run `bundle install' to ensure you have all dependencies.\n\n"
else
  require 'bundler/gem_helper'
  Bundler::GemHelper.install_tasks :dir => File.dirname(__FILE__)
end

require 'rake/clean'
CLEAN << "pkg" << "doc" << Dir['integration/**/target']

unless Rake::Application.method_defined? :last_comment
  Rake::Application.module_eval do
    alias_method :last_comment, :last_description
  end
end # Rake 11 compatibility (due rspec/core/rake_task < 3.0)

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = ['--color', "--format documentation"]
end

task :default => :spec

# use Mavenfile to define :jar task
require 'maven/ruby/maven'
mvn = Maven::Ruby::Maven.new
if defined?(JRUBY_VERISON) && ! (JRUBY_VERSION =~ /^9.0/)
  mvn.inherit_jruby_version
end

desc 'compile java sources and build jar'
task :jar do
  mvn.prepare_package
end

desc 'run some integration test'
task :integration do
  mvn.verify
end

desc 'generate the pom.xml from the Mavenfile'
task :pom do
  mvn.validate('-Dpolyglot.dump.pom=pom.xml')
end

# Make sure jar gets compiled before the gem is built
task :build => :jar

load_gemspec = lambda do
  Gem::Specification.load(File.expand_path('warbler.gemspec', File.dirname(__FILE__)))
end

require 'rdoc/task'
RDoc::Task.new(:docs) do |rd|
  gemspec = load_gemspec.call
  rd.rdoc_dir = "doc"
  rd.rdoc_files.include("README.rdoc", "History.txt", "LICENSE.txt")
  rd.rdoc_files += gemspec.require_paths
  rd.options << '--title' << "#{gemspec.name}-#{gemspec.version} Documentation"
  rd.options += gemspec.rdoc_options
end

task :release_docs => :docs do
  config = YAML.load(File.read(File.expand_path("~/.rubyforge/user-config.yml"))) rescue nil
  if config
    gemspec = load_gemspec.call
    dir  = "/var/www/gforge-projects/#{gemspec.rubyforge_project}/#{gemspec.name}"
    dest = "#{config["username"]}@rubyforge.org:#{dir}"
    sh %{rsync -rl --delete doc/ #{dest}}
  end
end
task :release => :release_docs
