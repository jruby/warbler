# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{warbler}
  s.version = "0.9.14"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Nick Sieger"]
  s.date = %q{2009-08-26}
  s.default_executable = %q{warble}
  s.description = %q{Warbler is a gem to make a .war file out of a Rails, Merb, or Rack-based
application. The intent is to provide a minimal, flexible, ruby-like way to
bundle up all of your application files for deployment to a Java application
server.}
  s.email = %q{nick@nicksieger.com}
  s.executables = ["warble"]
  s.extra_rdoc_files = ["History.txt", "Manifest.txt", "README.txt", "LICENSES.txt"]
  s.files = ["History.txt", "Manifest.txt", "README.txt", "LICENSES.txt", "Rakefile", "web.xml.erb", "bin/warble", "generators/warble/templates/warble.rb", "generators/warble/warble_generator.rb", "lib/jruby-rack-0.9.5.jar", "lib/warbler/config.rb", "lib/warbler/gems.rb", "lib/warbler/task.rb", "lib/warbler/version.rb", "lib/warbler.rb", "spec/sample/app/controllers/application.rb", "spec/sample/app/helpers/application_helper.rb", "spec/sample/config/boot.rb", "spec/sample/config/environment.rb", "spec/sample/config/environments/development.rb", "spec/sample/config/environments/production.rb", "spec/sample/config/environments/test.rb", "spec/sample/config/initializers/inflections.rb", "spec/sample/config/initializers/mime_types.rb", "spec/sample/config/initializers/new_rails_defaults.rb", "spec/sample/config/routes.rb", "spec/spec_helper.rb", "spec/warbler/config_spec.rb", "spec/warbler/gems_spec.rb", "spec/warbler/task_spec.rb", "tasks/warbler.rake"]
  s.homepage = %q{http://caldersphere.rubyforge.org/warbler}
  s.rdoc_options = ["--main", "README.txt"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{caldersphere}
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{Warbler chirpily constructs .war files of your Rails applications.}
  s.test_files = ["spec/warbler/config_spec.rb", "spec/warbler/gems_spec.rb", "spec/warbler/task_spec.rb"]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<rake>, [">= 0.7.3"])
      s.add_runtime_dependency(%q<jruby-jars>, [">= 1.3.1"])
    else
      s.add_dependency(%q<rake>, [">= 0.7.3"])
      s.add_dependency(%q<jruby-jars>, [">= 1.3.1"])
    end
  else
    s.add_dependency(%q<rake>, [">= 0.7.3"])
    s.add_dependency(%q<jruby-jars>, [">= 1.3.1"])
  end
end
