#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

unless defined? Bundler
  puts "\nPlease `gem install bundler' and run `bundle install' to ensure you have all dependencies and run ininside a bundler context 'bundle exec rake'.\n\n"
  raise
end

require 'bundler/gem_helper'
gem_helper = Bundler::GemHelper.new(File.dirname(__FILE__))
gem_helper.install
gemspec = gem_helper.gemspec

require 'rake/clean'
CLEAN << "pkg" << "doc"

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = ['--color', "--format documentation"]
end

task :default => :spec

# use Mavenfile to define :jar task
require 'maven/ruby/tasks'

desc 'run some integration test'
task :integration do
  maven.verify
end

# Make sure jar gets compiled before the gem is built
task :build => :jar

require 'rdoc/task'
RDoc::Task.new(:docs) do |rd|
  rd.rdoc_dir = "doc"
  rd.rdoc_files.include("README.rdoc", "History.txt", "LICENSE.txt")
  rd.rdoc_files += gemspec.require_paths
  rd.options << '--title' << "#{gemspec.name}-#{gemspec.version} Documentation"
  rd.options += gemspec.rdoc_options
end

task :release_docs => :docs do
  config = YAML.load(File.read(File.expand_path("~/.rubyforge/user-config.yml"))) rescue nil
  if config
    dir  = "/var/www/gforge-projects/#{gemspec.rubyforge_project}/#{gemspec.name}"
    dest = "#{config["username"]}@rubyforge.org:#{dir}"
    sh %{rsync -rl --delete doc/ #{dest}}
  end
end
task :release => :release_docs
