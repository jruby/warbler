# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "ruby-maven-libs"
  s.version = "3.1.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Christian Meier"]
  s.date = "2013-08-27"
  s.description = "maven distribution as gem - no ruby executables !"
  s.email = ["m.kristian@web.de"]
  s.extra_rdoc_files = ["NOTICE.txt", "LICENSE.txt", "README.txt"]
  s.files = ["NOTICE.txt", "LICENSE.txt", "README.txt"]
  s.homepage = "https://github.com/tesla/tesla-polyglot/tree/master/tesla-polyglot-gem/ruby-maven-libs"
  s.licenses = ["APL"]
  s.require_paths = ["ruby"]
  s.rubygems_version = "1.8.24"
  s.summary = "maven distribution as gem"

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
