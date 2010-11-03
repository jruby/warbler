# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{sample_jar}
  s.version = "1.0.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Nick Sieger"]
  s.date = %q{2010-11-03}
  s.default_executable = %q{sample_jar}
  s.description = %q{Sample jar application for Warbler specs.}
  s.email = ["nick@nicksieger.com"]
  s.executables = ["sample_jar"]
  s.extra_rdoc_files = ["History.txt", "Manifest.txt", "README.txt"]
  s.files = [".autotest", "History.txt", "Manifest.txt", "README.txt", "Rakefile", "bin/sample_jar", "lib/sample_jar.rb", "test/test_sample_jar.rb"]
  s.rdoc_options = ["--main", "README.txt"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{sample_jar}
  s.rubygems_version = %q{1.3.7}
  s.summary = %q{Sample jar application for Warbler specs.}
  s.test_files = ["test/test_sample_jar.rb"]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<rubyforge>, [">= 2.0.4"])
      s.add_development_dependency(%q<hoe>, [">= 2.6.2"])
    else
      s.add_dependency(%q<rubyforge>, [">= 2.0.4"])
      s.add_dependency(%q<hoe>, [">= 2.6.2"])
    end
  else
    s.add_dependency(%q<rubyforge>, [">= 2.0.4"])
    s.add_dependency(%q<hoe>, [">= 2.6.2"])
  end
end
