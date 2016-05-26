# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require 'warbler/version'

Gem::Specification.new do |gem|
  gem.name = "warbler"
  gem.version = Warbler::VERSION
  gem.platform = Gem::Platform::RUBY
  gem.homepage = "https://github.com/jruby/warbler"
  gem.license = 'MIT'
  gem.authors = ["Nick Sieger"]
  gem.email = "nick@nicksieger.com"
  gem.summary = "Warbler chirpily constructs .war files of your Rails applications."
  gem.description = %q{Warbler is a gem to make a Java jar or war file out of any Ruby,
Rails, or Rack application. Warbler provides a minimal, flexible, Ruby-like way to
bundle up all of your application files for deployment to a Java environment.}

  gem.files         = `git ls-files`.split("\n").
    reject { |file| file =~ /^\./ }. # .gitignore, .travis.yml
    reject { |file| file =~ /^spec|test\// }. # spec/**/*.spec
    reject { |file| file =~ /^integration\// }. # (un-used) *.rake files
    reject { |file| file =~ /^rakelib\// } # (un-used) *.rake files
  gem.test_files    = [] # tests and specs add 700k to the gem, so don't include them
  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.require_paths = ["lib"]

  gem.rdoc_options = ["--main", "README.rdoc", "-H", "-f", "darkfish"]

  gem.add_runtime_dependency 'rake', ['>= 10.1.0']
  gem.add_runtime_dependency 'jruby-jars', ['>= 9.0.0.0']
  gem.add_runtime_dependency 'jruby-rack', ['>= 1.1.1', '< 1.3']
  gem.add_runtime_dependency 'rubyzip', ['~> 1.0', '< 1.4']
  gem.add_development_dependency 'jbundler', '~> 0.9'
  gem.add_development_dependency 'rspec', '~> 2.10'
end
