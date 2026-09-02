source "https://rubygems.org/"

gemspec

group :development, :test do
  gem 'rdoc', :require => nil
  gem 'rspec', '~> 3.0'
  gem 'drb', '~> 2.2', '>= 2.2.3'
  gem 'ruby-maven', '~> 3.9'

  # JBundler is unsupported on JRuby 10.1
  gem 'jbundler', '~> 0.9.5' if RUBY_VERSION.to_f < 4.0

  if defined?(JRUBY_VERSION)
    # force jruby-jars to use current JRuby version for testing
    gem 'jruby-jars', '~> ' + JRUBY_VERSION.split('.')[0..2].join('.')
  end
end
