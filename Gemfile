source "https://rubygems.org/"

gemspec

gem 'rubyzip', ENV['RUBYZIP_VERSION'] if ENV['RUBYZIP_VERSION']
gem 'rake', ENV['RAKE_VERSION'], :require => nil if ENV['RAKE_VERSION']

group :development, :test do
  gem 'rdoc', ['>= 3.10', '< 4.3'], :require => nil
end
