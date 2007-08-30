require 'spec/rake/spectask'

MANIFEST = FileList["History.txt", "Manifest.txt", "README.txt", "LICENSES.txt", "Rakefile",
  "*.erb", "bin/*", "generators/**/*", "lib/**/*.rb", "spec/**/*.rb", "tasks/**/*.rake"]

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
    p.extra_deps.reject!{|d| d.first == "hoe"}
    p.test_globs = ["spec/**/*_spec.rb"]
  end
  hoe.spec.files = MANIFEST
  hoe.spec.dependencies.delete_if { |dep| dep.name == "hoe" }
rescue LoadError
  puts "You really need Hoe installed to be able to package this gem"
end

# Hoe insists on setting task :default => :test
# !@#$ no easy way to empty the default list of prerequisites
Rake::Task['default'].send :instance_variable_set, "@prerequisites", FileList[]

task :default => :spec

Spec::Rake::SpecTask.new do |t|
  t.spec_opts ||= []
  t.spec_opts << "--diff" << "unified"
end
