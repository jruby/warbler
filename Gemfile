source "https://rubygems.org/"

gemspec

gem 'jbundler', git: 'https://github.com/mkristian/jbundler'

rubyzip_version = ENV['RUBYZIP_VERSION']
gem 'rubyzip', rubyzip_version if rubyzip_version && !rubyzip_version.empty?

group :development, :test do
  gem 'rdoc', ['>= 3.10', '< 4.3'], :require => nil
end

gem "jar-dependencies", "0.4.1"
