# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{warbler}
  s.version = "1.3.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Nick Sieger"]
  s.date = %q{2011-05-24}
  s.description = %q{Warbler is a gem to make a Java jar or war file out of any Ruby,
Rails, Merb, or Rack application. Warbler provides a minimal,
flexible, Ruby-like way to bundle up all of your application files for
deployment to a Java environment.}
  s.email = %q{nick@nicksieger.com}
  s.executables = ["warble"]
  s.extra_rdoc_files = ["History.txt", "LICENSE.txt", "Manifest.txt", "README.txt"]
  s.files = ["Gemfile", "History.txt", "LICENSE.txt", "Manifest.txt", "README.txt", "Rakefile", "bin/warble", "ext/JarMain.java", "ext/WarMain.java", "ext/WarblerJar.java", "ext/WarblerJarService.java", "lib/warbler.rb", "lib/warbler/application.rb", "lib/warbler/config.rb", "lib/warbler/gems.rb", "lib/warbler/jar.rb", "lib/warbler/task.rb", "lib/warbler/templates/bundler.erb", "lib/warbler/templates/config.erb", "lib/warbler/templates/jar.erb", "lib/warbler/templates/rack.erb", "lib/warbler/templates/rails.erb", "lib/warbler/templates/war.erb", "lib/warbler/traits.rb", "lib/warbler/traits/bundler.rb", "lib/warbler/traits/gemspec.rb", "lib/warbler/traits/jar.rb", "lib/warbler/traits/merb.rb", "lib/warbler/traits/nogemspec.rb", "lib/warbler/traits/rack.rb", "lib/warbler/traits/rails.rb", "lib/warbler/traits/war.rb", "lib/warbler/version.rb", "lib/warbler/war.rb", "lib/warbler_jar.jar", "spec/drb_helper.rb", "spec/sample_bundler/Gemfile.lock", "spec/sample_bundler/config.ru", "spec/sample_bundler/vendor/bundle/jruby/1.8/cache/rake-0.8.7.gem", "spec/sample_bundler/vendor/bundle/jruby/1.8/gems/rake-0.8.7/lib/rake.rb", "spec/sample_bundler/vendor/bundle/jruby/1.8/specifications/rake-0.8.7.gemspec", "spec/sample_bundler/vendor/bundle/ruby/1.8/cache/rake-0.8.7.gem", "spec/sample_bundler/vendor/bundle/ruby/1.8/gems/rake-0.8.7/lib/rake.rb", "spec/sample_bundler/vendor/bundle/ruby/1.8/specifications/rake-0.8.7.gemspec", "spec/sample_bundler/vendor/bundle/ruby/1.9.1/cache/rake-0.8.7.gem", "spec/sample_bundler/vendor/bundle/ruby/1.9.1/gems/rake-0.8.7/lib/rake.rb", "spec/sample_bundler/vendor/bundle/ruby/1.9.1/specifications/rake-0.8.7.gemspec", "spec/sample_jar/History.txt", "spec/sample_jar/Manifest.txt", "spec/sample_jar/README.txt", "spec/sample_jar/lib/sample_jar.rb", "spec/sample_jar/sample_jar.gemspec", "spec/sample_jar/test/test_sample_jar.rb", "spec/sample_war/app/controllers/application.rb", "spec/sample_war/app/helpers/application_helper.rb", "spec/sample_war/config/boot.rb", "spec/sample_war/config/database.yml", "spec/sample_war/config/environment.rb", "spec/sample_war/config/environments/development.rb", "spec/sample_war/config/environments/production.rb", "spec/sample_war/config/environments/test.rb", "spec/sample_war/config/initializers/inflections.rb", "spec/sample_war/config/initializers/mime_types.rb", "spec/sample_war/config/initializers/new_rails_defaults.rb", "spec/sample_war/config/routes.rb", "spec/sample_war/lib/tasks/utils.rake", "spec/sample_war/public/404.html", "spec/sample_war/public/422.html", "spec/sample_war/public/500.html", "spec/sample_war/public/favicon.ico", "spec/sample_war/public/index.html", "spec/sample_war/public/robots.txt", "spec/spec_helper.rb", "spec/warbler/application_spec.rb", "spec/warbler/bundler_spec.rb", "spec/warbler/config_spec.rb", "spec/warbler/gems_spec.rb", "spec/warbler/jar_spec.rb", "spec/warbler/task_spec.rb", "spec/warbler/traits_spec.rb", "spec/warbler/war_spec.rb", "warble.rb", "web.xml.erb"]
  s.homepage = %q{http://caldersphere.rubyforge.org/warbler}
  s.rdoc_options = ["--main", "README.txt", "-SHN", "-f", "darkfish"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{caldersphere}
  s.rubygems_version = %q{1.7.2}
  s.summary = %q{Warbler chirpily constructs .war files of your Rails applications.}

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<rake>, ["~> 0.8.7"])
      s.add_runtime_dependency(%q<jruby-jars>, [">= 1.4.0"])
      s.add_runtime_dependency(%q<jruby-rack>, [">= 1.0.0"])
      s.add_runtime_dependency(%q<rubyzip>, [">= 0.9.4"])
      s.add_development_dependency(%q<rubyforge>, [">= 2.0.4"])
      s.add_development_dependency(%q<hoe>, [">= 2.9.1"])
    else
      s.add_dependency(%q<rake>, ["~> 0.8.7"])
      s.add_dependency(%q<jruby-jars>, [">= 1.4.0"])
      s.add_dependency(%q<jruby-rack>, [">= 1.0.0"])
      s.add_dependency(%q<rubyzip>, [">= 0.9.4"])
      s.add_dependency(%q<rubyforge>, [">= 2.0.4"])
      s.add_dependency(%q<hoe>, [">= 2.9.1"])
    end
  else
    s.add_dependency(%q<rake>, ["~> 0.8.7"])
    s.add_dependency(%q<jruby-jars>, [">= 1.4.0"])
    s.add_dependency(%q<jruby-rack>, [">= 1.0.0"])
    s.add_dependency(%q<rubyzip>, [">= 0.9.4"])
    s.add_dependency(%q<rubyforge>, [">= 2.0.4"])
    s.add_dependency(%q<hoe>, [">= 2.9.1"])
  end
end
