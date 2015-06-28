source "https://rubygems.org/"

gemspec

group :development do
  gem "jruby-openssl", :platform => :jruby
  gem "rcov", ">= 0.9.8", :platform => :mri_18
  gem "childprocess", :platform => :mri
  gem "maven-tools", "~> 0.34.5"
end

if RUBY_VERSION < "1.9"
  gem 'rubyzip', '~> 0.9'
end
