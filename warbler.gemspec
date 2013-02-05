# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require 'warbler/version'

Gem::Specification.new do |gem|
  gem.name = "warbler"
  gem.version = Warbler::VERSION
  gem.platform = Gem::Platform::RUBY
  gem.homepage = "http://caldersphere.rubyforge.org/warbler"
  gem.authors = ["Nick Sieger"]
  gem.email = "nick@nicksieger.com"
  gem.summary = "Warbler chirpily constructs .war files of your Rails applications."
  gem.description = %q{Warbler is a gem to make a Java jar or war file out of any Ruby,
Rails, Merb, or Rack application. Warbler provides a minimal,
flexible, Ruby-like way to bundle up all of your application files for
deployment to a Java environment.}

  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.require_paths = ["lib"]

  gem.rdoc_options = ["--main", "README.rdoc", "-H", "-f", "darkfish"]
  gem.rubyforge_project = "caldersphere"

  gem.add_runtime_dependency 'rake', [">= 0.9.6"]
  gem.add_runtime_dependency 'jruby-jars', [">= 1.5.6"]
  gem.add_runtime_dependency 'jruby-rack', [">= 1.0.0"]
  gem.add_runtime_dependency 'rubyzip', [">= 0.9.8"]
  gem.add_development_dependency 'rspec', "~> 2.10"
end
