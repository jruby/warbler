source "https://rubygems.org/"

gemspec

group :development do
  gem "jruby-openssl", :platform => :jruby
  gem "rcov", ">= 0.9.8", :platform => :mri_18
  gem "childprocess", :platform => :mri
end

gem 'rubyzip', ENV['RUBYZIP_VERSION'] if ENV['RUBYZIP_VERSION']
gem 'rake', ENV['RAKE_VERSION'], :require => nil if ENV['RAKE_VERSION']

group :development, :test do
  gem 'rdoc', ['>= 3.10', '< 4.3'], :require => nil
end
