# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "backports"
  s.version = "3.3.5"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Marc-Andr\u{e9} Lafortune"]
  s.date = "2013-10-10"
  s.description = "Essential backports that enable many of the nice features of Ruby 1.8.7 up to 2.0.0 for earlier versions."
  s.email = ["github@marc-andre.ca"]
  s.homepage = "http://github.com/marcandre/backports"
  s.require_paths = ["lib"]
  s.rubygems_version = "1.8.24"
  s.summary = "Backports of Ruby features for older Ruby."

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
