source "https://rubygems.org/"

gemspec

group :development, :test do
  gem 'rdoc', '~> 7.0', :require => nil

  if defined?(JRUBY_VERSION)
    # force jruby-jars to use current JRuby version for testing
    gem 'jruby-jars', '~> ' + JRUBY_VERSION.split('.')[0..2].join('.')
  end
end
