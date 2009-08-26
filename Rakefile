require 'spec/rake/spectask'
require 'spec/rake/verify_rcov'

MANIFEST = FileList["History.txt", "Manifest.txt", "README.txt", "LICENSES.txt", "Rakefile",
  "*.erb", "bin/*", "generators/**/*", "lib/**/*", "spec/**/*.rb", "tasks/**/*.rake"]

begin
  File.open("Manifest.txt", "w") {|f| MANIFEST.each {|n| f << "#{n}\n"} }
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
    p.extra_deps += [['rake', '>= 0.7.3'], ['jruby-jars', '>= 1.3.1']]
    p.test_globs = ["spec/**/*_spec.rb"]
  end
  hoe.spec.files = MANIFEST
  hoe.spec.dependencies.delete_if { |dep| dep.name == "hoe" }

  task :gemspec do
    File.open("#{hoe.name}.gemspec", "w") {|f| f << hoe.spec.to_ruby }
  end
  task :package => :gemspec
rescue LoadError
  puts "You really need Hoe installed to be able to package this gem"
end

# Hoe insists on setting task :default => :test
# !@#$ no easy way to empty the default list of prerequisites
Rake::Task['default'].send :instance_variable_set, "@prerequisites", FileList[]
Rake::Task['default'].send :instance_variable_set, "@actions", []

if defined?(JRUBY_VERSION)
  task :default => :spec
else
  task :default => :rcov_verify
end

Spec::Rake::SpecTask.new do |t|
  t.spec_opts ||= []
  t.spec_opts << "--options" << "spec/spec.opts"
end

Spec::Rake::SpecTask.new("spec:rcov") do |t|
  t.rcov = true
end

# so we don't confuse autotest
RCov::VerifyTask.new(:rcov_verify) do |t|
  t.threshold = 100
end

task :rcov_verify => "spec:rcov"
