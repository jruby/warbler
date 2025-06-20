source "https://rubygems.org/"

gemspec

rubyzip_version = ENV['RUBYZIP_VERSION']
gem 'rubyzip', rubyzip_version if rubyzip_version && !rubyzip_version.empty?

# override default maven-tools used by bundler
gem 'maven-tools', '1.2.3'

group :development, :test do
  gem 'rdoc', ['>= 3.10', '< 4.3'], :require => nil
end
