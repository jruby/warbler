# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "descendants_tracker"
  s.version = "0.0.3"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Dan Kubb", "Piotr Solnica", "Markus Schirp"]
  s.date = "2013-10-05"
  s.description = "Module that adds descendant tracking to a class"
  s.email = ["dan.kubb@gmail.com", "piotr.solnica@gmail.com", "mbj@schirp-dso.com"]
  s.extra_rdoc_files = ["LICENSE", "README.md", "TODO"]
  s.files = ["LICENSE", "README.md", "TODO"]
  s.homepage = "https://github.com/dkubb/descendants_tracker"
  s.require_paths = ["lib"]
  s.rubygems_version = "1.8.24"
  s.summary = "Module that adds descendant tracking to a class"

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<rake>, ["~> 10.1.0"])
      s.add_development_dependency(%q<rspec>, ["~> 2.13.0"])
      s.add_development_dependency(%q<yard>, ["~> 0.8.6.1"])
    else
      s.add_dependency(%q<rake>, ["~> 10.1.0"])
      s.add_dependency(%q<rspec>, ["~> 2.13.0"])
      s.add_dependency(%q<yard>, ["~> 0.8.6.1"])
    end
  else
    s.add_dependency(%q<rake>, ["~> 10.1.0"])
    s.add_dependency(%q<rspec>, ["~> 2.13.0"])
    s.add_dependency(%q<yard>, ["~> 0.8.6.1"])
  end
end
