# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{warbler}
  s.version = "1.3.3"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = [%q{Nick Sieger}]
  s.date = %q{2011-12-01}
  s.description = %q{Warbler is a gem to make a Java jar or war file out of any Ruby,
Rails, Merb, or Rack application. Warbler provides a minimal,
flexible, Ruby-like way to bundle up all of your application files for
deployment to a Java environment.}
  s.email = %q{nick@nicksieger.com}
  s.executables = [%q{warble}]
  s.extra_rdoc_files = [%q{History.txt}, %q{LICENSE.txt}, %q{Manifest.txt}]
  s.files = [%q{Gemfile}, %q{History.txt}, %q{LICENSE.txt}, %q{Manifest.txt}, %q{README.rdoc}, %q{Rakefile}, %q{bin/warble}, %q{ext/JarMain.java}, %q{ext/WarMain.java}, %q{ext/WarblerJar.java}, %q{ext/WarblerJarService.java}, %q{lib/warbler.rb}, %q{lib/warbler/application.rb}, %q{lib/warbler/config.rb}, %q{lib/warbler/gems.rb}, %q{lib/warbler/jar.rb}, %q{lib/warbler/pathmap_helper.rb}, %q{lib/warbler/rake_helper.rb}, %q{lib/warbler/task.rb}, %q{lib/warbler/templates/bundler.erb}, %q{lib/warbler/templates/config.erb}, %q{lib/warbler/templates/jar.erb}, %q{lib/warbler/templates/rack.erb}, %q{lib/warbler/templates/rails.erb}, %q{lib/warbler/templates/war.erb}, %q{lib/warbler/traits.rb}, %q{lib/warbler/traits/bundler.rb}, %q{lib/warbler/traits/gemspec.rb}, %q{lib/warbler/traits/jar.rb}, %q{lib/warbler/traits/merb.rb}, %q{lib/warbler/traits/nogemspec.rb}, %q{lib/warbler/traits/rack.rb}, %q{lib/warbler/traits/rails.rb}, %q{lib/warbler/traits/war.rb}, %q{lib/warbler/version.rb}, %q{lib/warbler/war.rb}, %q{lib/warbler_jar.jar}, %q{spec/drb_helper.rb}, %q{spec/sample_bundler/Gemfile.lock}, %q{spec/sample_bundler/config.ru}, %q{spec/sample_bundler/vendor/bundle/jruby/1.8/cache/rake-0.8.7.gem}, %q{spec/sample_bundler/vendor/bundle/jruby/1.8/gems/rake-0.8.7/lib/rake.rb}, %q{spec/sample_bundler/vendor/bundle/jruby/1.8/specifications/rake-0.8.7.gemspec}, %q{spec/sample_bundler/vendor/bundle/ruby/1.8/cache/rake-0.8.7.gem}, %q{spec/sample_bundler/vendor/bundle/ruby/1.8/gems/rake-0.8.7/lib/rake.rb}, %q{spec/sample_bundler/vendor/bundle/ruby/1.8/specifications/rake-0.8.7.gemspec}, %q{spec/sample_bundler/vendor/bundle/ruby/1.9.1/cache/rake-0.8.7.gem}, %q{spec/sample_bundler/vendor/bundle/ruby/1.9.1/gems/rake-0.8.7/lib/rake.rb}, %q{spec/sample_bundler/vendor/bundle/ruby/1.9.1/specifications/rake-0.8.7.gemspec}, %q{spec/sample_jar/History.txt}, %q{spec/sample_jar/Manifest.txt}, %q{spec/sample_jar/README.txt}, %q{spec/sample_jar/lib/sample_jar.rb}, %q{spec/sample_jar/sample_jar.gemspec}, %q{spec/sample_jar/test/test_sample_jar.rb}, %q{spec/sample_war/app/controllers/application.rb}, %q{spec/sample_war/app/helpers/application_helper.rb}, %q{spec/sample_war/config/boot.rb}, %q{spec/sample_war/config/database.yml}, %q{spec/sample_war/config/environment.rb}, %q{spec/sample_war/config/environments/development.rb}, %q{spec/sample_war/config/environments/production.rb}, %q{spec/sample_war/config/environments/test.rb}, %q{spec/sample_war/config/initializers/inflections.rb}, %q{spec/sample_war/config/initializers/mime_types.rb}, %q{spec/sample_war/config/initializers/new_rails_defaults.rb}, %q{spec/sample_war/config/routes.rb}, %q{spec/sample_war/lib/tasks/utils.rake}, %q{spec/sample_war/public/404.html}, %q{spec/sample_war/public/422.html}, %q{spec/sample_war/public/500.html}, %q{spec/sample_war/public/favicon.ico}, %q{spec/sample_war/public/index.html}, %q{spec/sample_war/public/robots.txt}, %q{spec/spec_helper.rb}, %q{spec/warbler/application_spec.rb}, %q{spec/warbler/bundler_spec.rb}, %q{spec/warbler/config_spec.rb}, %q{spec/warbler/gems_spec.rb}, %q{spec/warbler/jar_spec.rb}, %q{spec/warbler/task_spec.rb}, %q{spec/warbler/traits_spec.rb}, %q{spec/warbler/war_spec.rb}, %q{warble.rb}, %q{web.xml.erb}]
  s.homepage = %q{http://caldersphere.rubyforge.org/warbler}
  s.rdoc_options = [%q{--main}, %q{README.rdoc}, %q{-SHN}, %q{-f}, %q{darkfish}]
  s.require_paths = [%q{lib}]
  s.rubyforge_project = %q{caldersphere}
  s.rubygems_version = %q{1.8.9}
  s.summary = %q{Warbler chirpily constructs .war files of your Rails applications.}

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<rake>, [">= 0.8.7"])
      s.add_runtime_dependency(%q<jruby-jars>, [">= 1.4.0"])
      s.add_runtime_dependency(%q<jruby-rack>, [">= 1.0.0"])
      s.add_runtime_dependency(%q<rubyzip>, [">= 0.9.4"])
      s.add_development_dependency(%q<rubyforge>, [">= 2.0.4"])
      s.add_development_dependency(%q<hoe>, ["~> 2.12"])
    else
      s.add_dependency(%q<rake>, [">= 0.8.7"])
      s.add_dependency(%q<jruby-jars>, [">= 1.4.0"])
      s.add_dependency(%q<jruby-rack>, [">= 1.0.0"])
      s.add_dependency(%q<rubyzip>, [">= 0.9.4"])
      s.add_dependency(%q<rubyforge>, [">= 2.0.4"])
      s.add_dependency(%q<hoe>, ["~> 2.12"])
    end
  else
    s.add_dependency(%q<rake>, [">= 0.8.7"])
    s.add_dependency(%q<jruby-jars>, [">= 1.4.0"])
    s.add_dependency(%q<jruby-rack>, [">= 1.0.0"])
    s.add_dependency(%q<rubyzip>, [">= 0.9.4"])
    s.add_dependency(%q<rubyforge>, [">= 2.0.4"])
    s.add_dependency(%q<hoe>, ["~> 2.12"])
  end
end
