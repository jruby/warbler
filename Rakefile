#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

begin
  require 'bundler/setup'
rescue LoadError
  puts $!
  puts "Please install Bundler and run 'bundle install' to ensure you have all dependencies"
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

jar_file = "lib/warbler_jar.jar"
begin
  require 'ant'
  directory "pkg/classes"
  CLEAN << "pkg"

  file jar_file => FileList['ext/*.java', 'pkg/classes'] do
    rm_rf FileList['pkg/classes/**/*']
    ant.javac :srcdir => "ext", :includes => "*.java", :destdir => "pkg/classes",
      :source => "1.5", :target => "1.5", :debug => true,
      :classpath => "${java.class.path}:${sun.boot.class.path}",
      :includeantRuntime => false

    ant.jar :basedir => "pkg/classes", :destfile => jar_file, :includes => "*.class"
  end

  desc "Compile and jar the Warbler Java helper classes"
  task :jar => jar_file
rescue LoadError
  task :jar do
    puts "Run 'jar' with JRuby to re-compile the java jar booster"
  end
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
    sh %{rsync -av --delete doc/ #{dest}}
  end
end
task :release => :release_docs
