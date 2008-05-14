require 'spec/rake/spectask'
require 'spec/rake/verify_rcov'

MANIFEST = FileList["History.txt", "Manifest.txt", "README.txt", "LICENSES.txt", "Rakefile",
  "*.erb", "bin/*", "generators/**/*", "lib/**/*", "spec/**/*.rb", "tasks/**/*.rake"]

begin
  File.open("Manifest.txt", "w") {|f| MANIFEST.each {|n| f << "#{n}\n"} }
  require 'hoe'
  require File.dirname(__FILE__) + '/lib/warbler/version'
  hoe = Hoe.new("warbler", Warbler::VERSION) do |p|
    p.rubyforge_name = "caldersphere"
    p.url = "http://caldersphere.rubyforge.org/warbler"
    p.author = "Nick Sieger"
    p.email = "nick@nicksieger.com"
    p.summary = "Warbler chirpily constructs .war files of your Rails applications."
    p.changes = p.paragraphs_of('History.txt', 0..1).join("\n\n")
    p.description = p.paragraphs_of('README.txt', 0...1).join("\n\n")
    p.extra_deps << ['rake', '>= 0.7.3']
    p.test_globs = ["spec/**/*_spec.rb"]
    p.rdoc_pattern = /\.(rb|txt)/
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

task :default => :rcov

Spec::Rake::SpecTask.new do |t|
  t.spec_opts ||= []
  t.spec_opts << "--options" << "spec/spec.opts"
end

Spec::Rake::SpecTask.new("spec:rcov") do |t|
  t.rcov = true
  t.rcov_opts << '--exclude gems/*'
end

# so we don't confuse autotest
RCov::VerifyTask.new(:rcov) do |t|
  t.threshold = 100
end

task "spec:rcov" do
  rm_f "Manifest.txt"
end
task :rcov => "spec:rcov"
