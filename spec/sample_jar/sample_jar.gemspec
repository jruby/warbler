# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "sample_jar"
  s.version = "1.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Nick Sieger"]
  s.date = "2012-03-09"
  s.description = ""
  s.email = ["nick@nicksieger.com"]
  s.executables = ["sample_jar"]
  s.files = ["History.txt", "Rakefile", "README.txt", "sample_jar.gemspec", "bin/sample_jar", "lib/sample_jar.rb", "test/test_sample_jar.rb"]
  s.homepage = ""
  s.require_paths = ["lib"]
  s.rubygems_version = "1.8.15"
  s.summary = ""

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<rubyzip>, [">= 0"])
    else
      s.add_dependency(%q<rubyzip>, [">= 0"])
    end
  else
    s.add_dependency(%q<rubyzip>, [">= 0"])
  end
end
