source "https://rubygems.org/"

gemspec

# override default maven-tools used by bundler
gem 'maven-tools', '1.2.3'


group :development, :test do
  gem 'rdoc', ['>= 3.10', '< 7'], :require => nil

  # force jruby-jars to use current JRuby version for testing
  gem 'jruby-jars', '~> ' + JRUBY_VERSION.split('.')[0..1].join('.')
end
