# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "virtus"
  s.version = "0.5.5"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Piotr Solnica"]
  s.date = "2013-05-30"
  s.description = "Attributes on Steroids for Plain Old Ruby Objects"
  s.email = ["piotr.solnica@gmail.com"]
  s.extra_rdoc_files = ["LICENSE", "README.md", "TODO"]
  s.files = ["LICENSE", "README.md", "TODO"]
  s.homepage = "https://github.com/solnic/virtus"
  s.require_paths = ["lib"]
  s.rubygems_version = "1.8.24"
  s.summary = "Attributes on Steroids for Plain Old Ruby Objects"

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<backports>, ["~> 3.3"])
      s.add_runtime_dependency(%q<descendants_tracker>, ["~> 0.0.1"])
    else
      s.add_dependency(%q<backports>, ["~> 3.3"])
      s.add_dependency(%q<descendants_tracker>, ["~> 0.0.1"])
    end
  else
    s.add_dependency(%q<backports>, ["~> 3.3"])
    s.add_dependency(%q<descendants_tracker>, ["~> 0.0.1"])
  end
end
