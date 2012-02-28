#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

begin
  require 'bundler'
  Bundler::GemHelper.install_tasks
  require 'bundler/setup'
rescue LoadError
  puts $!
  puts "Please install Bundler and run 'bundle install' to ensure you have all dependencies"
end

require 'rake/clean'
require 'spec/rake/spectask'

Spec::Rake::SpecTask.new do |t|
  t.spec_opts ||= []
  t.spec_opts << "--options" << "spec/spec.opts"
end

Spec::Rake::SpecTask.new("spec:rcov") do |t|
  t.spec_opts ||= []
  t.spec_opts << "--options" << "spec/spec.opts"
  t.rcov_opts ||= []
  t.rcov_opts << "-x" << "/gems/"
  t.rcov = true
end

require 'spec/rake/verify_rcov'

RCov::VerifyTask.new(:rcov => "spec:rcov") do |t|
  t.threshold = 100
end

task :default => :spec

desc "Compile and jar the Warbler Java helper classes"
begin
  require 'ant'
  task :jar => :compile do
    ant.jar :basedir => "pkg/classes", :destfile => "lib/warbler_jar.jar", :includes => "*.class"
  end

  directory "pkg/classes"
  task :compile => "pkg/classes" do |t|
    ant.javac :srcdir => "ext", :destdir => t.prerequisites.first,
    :source => "1.5", :target => "1.5", :debug => true,
    :classpath => "${java.class.path}:${sun.boot.class.path}",
    :includeantRuntime => false
  end
rescue LoadError
  task :jar do
    puts "Run 'jar' with JRuby >= 1.5 to re-compile the java jar booster"
  end
end

# Make sure jar gets compiled before the gem is built
task Rake::Task['build'].prerequisites.first => :jar

task :warbler_jar => 'pkg' do
  ruby "-rubygems", "-Ilib", "-S", "bin/warble"
  mv "warbler.jar", "pkg/warbler-#{Warbler::VERSION}.jar"
end

task :build => :warbler_jar
