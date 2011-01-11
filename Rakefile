#--
# Copyright (c) 2010-2011 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

begin
  require 'bundler/setup'
rescue LoadError
  puts "Please install Bundler and run 'bundle install' to ensure you have all dependencies"
end

require 'spec/rake/spectask'
require 'spec/rake/verify_rcov'

MANIFEST = FileList["History.txt", "Manifest.txt", "README.txt", "Gemfile",
                    "LICENSE.txt", "Rakefile", "*.erb", "*.rb", "bin/*",
                    "ext/**/*", "lib/**/*", "spec/**/*.rb", "spec/sample*/**/*.*"
                   ].to_a.reject{|f| f=~%r{spec/sample/(MANIFEST|link|web.xml)}}.sort.uniq

begin
  File.open("Manifest.txt", "wb") {|f| MANIFEST.each {|n| f << "#{n}\n"} }
  require 'hoe'
  require File.dirname(__FILE__) + '/lib/warbler/version'
  hoe = Hoe.spec("warbler") do |p|
    p.version = Warbler::VERSION
    p.rubyforge_name = "caldersphere"
    p.url = "http://caldersphere.rubyforge.org/warbler"
    p.author = "Nick Sieger"
    p.email = "nick@nicksieger.com"
    p.summary = "Warbler chirpily constructs .war files of your Rails applications."
    p.changes = p.paragraphs_of('History.txt', 0..1).join("\n\n")
    p.description = p.paragraphs_of('README.txt', 1...2).join("\n\n")
    p.extra_deps += [['rake', '>= 0.8.7'], ['jruby-jars', '>= 1.4.0'], ['jruby-rack', '>= 1.0.0'], ['rubyzip', '>= 0.9.4']]
    p.clean_globs += %w(MANIFEST web.xml init.rb).map{|f| "spec/sample*/#{f}*" }
  end
  hoe.spec.files = MANIFEST
  hoe.spec.dependencies.delete_if { |dep| dep.name == "hoe" }
  hoe.spec.rdoc_options += ["-SHN", "-f", "darkfish"]

  task :gemspec do
    File.open("#{hoe.name}.gemspec", "w") {|f| f << hoe.spec.to_ruby }
  end
  task :package => :gemspec
rescue LoadError
  puts "You really need Hoe installed to be able to package this gem"
end

# Leave my tasks alone, Hoe
%w(default spec rcov).each do |task|
  Rake::Task[task].prerequisites.clear
  Rake::Task[task].actions.clear
end

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

RCov::VerifyTask.new(:rcov => "spec:rcov") do |t|
  t.threshold = 100
end

task :default => :spec

begin
  require 'ant'
  directory "pkg/classes"
  task :compile => "pkg/classes" do |t|
    ant.javac :srcdir => "ext", :destdir => t.prerequisites.first,
    :source => "1.5", :target => "1.5", :debug => true,
    :classpath => "${java.class.path}:${sun.boot.class.path}",
    :includeantRuntime => false
  end

  task :jar => :compile do
    ant.jar :basedir => "pkg/classes", :destfile => "lib/warbler_jar.jar", :includes => "*.class"
  end
rescue LoadError
  task :jar do
    puts "Run 'jar' with JRuby >= 1.5 to re-compile the java jar booster"
  end
end

# Make sure jar gets compiled before the gem is built
task Rake::Task['gem'].prerequisites.first => :jar

task :warbler_jar => 'pkg' do
  ruby "-rubygems", "-Ilib", "-S", "bin/warble"
  mv "warbler.jar", "pkg/warbler-#{Warbler::VERSION}.jar"
end

task :package => :warbler_jar
