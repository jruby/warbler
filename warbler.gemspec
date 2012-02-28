# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require 'warbler/version'
version = Warbler::VERSION
Gem::Specification.new do |s|
  s.name = "warbler"
  s.version = "1.3.4"
  s.platform = Gem::Platform::RUBY
  s.homepage = "http://caldersphere.rubyforge.org/warbler"
  s.authors = ["Nick Sieger"]
  s.email = "nick@nicksieger.com"
  s.summary = "Warbler chirpily constructs .war files of your Rails applications."
  s.description = %q{Warbler is a gem to make a Java jar or war file out of any Ruby,
Rails, Merb, or Rack application. Warbler provides a minimal,
flexible, Ruby-like way to bundle up all of your application files for
deployment to a Java environment.}


  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.rdoc_options = ["--main", "README.rdoc", "-SHN", "-f", "darkfish"]
  s.rubyforge_project = "caldersphere"

  s.add_runtime_dependency(%q<rake>, [">= 0.8.7"])
  s.add_runtime_dependency(%q<jruby-jars>, [">= 1.4.0"])
  s.add_runtime_dependency(%q<jruby-rack>, [">= 1.0.0"])
  s.add_runtime_dependency(%q<rubyzip>, [">= 0.9.4"])
end
