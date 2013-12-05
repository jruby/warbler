# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "maven-tools"
  s.version = "0.33.5"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Christian Meier"]
  s.date = "2013-11-03"
  s.description = "adds versions conversion from rubygems to maven and vice versa, ruby DSL for POM (Project Object Model from maven), pom generators, etc"
  s.email = ["m.kristian@web.de"]
  s.homepage = "http://github.com/torquebox/maven-tools"
  s.licenses = ["MIT"]
  s.require_paths = ["lib"]
  s.rubygems_version = "1.8.24"
  s.summary = "helpers for maven related tasks"

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<virtus>, ["~> 0.5"])
      s.add_development_dependency(%q<rake>, ["~> 10.0"])
      s.add_development_dependency(%q<minitest>, ["~> 4.4"])
      s.add_development_dependency(%q<rspec>, ["= 2.13.0"])
    else
      s.add_dependency(%q<virtus>, ["~> 0.5"])
      s.add_dependency(%q<rake>, ["~> 10.0"])
      s.add_dependency(%q<minitest>, ["~> 4.4"])
      s.add_dependency(%q<rspec>, ["= 2.13.0"])
    end
  else
    s.add_dependency(%q<virtus>, ["~> 0.5"])
    s.add_dependency(%q<rake>, ["~> 10.0"])
    s.add_dependency(%q<minitest>, ["~> 4.4"])
    s.add_dependency(%q<rspec>, ["= 2.13.0"])
  end
end
