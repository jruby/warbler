source "http://rubygems.org/"

# The use of the `gemspec` directive generates tons of warnings when running the specs.
# That's because some of the specs are testing Bundler, and Bundler detects this file.
# So if you see messages like the one below, you can ignore them.
#    warning: Bundler `path' components are not currently supported.
#    The `warbler-1.4.0.dev' component was not bundled.
#    Your application may fail to boot!

gemspec

group :development do
  gem "jruby-openssl", :platform => :jruby
  gem "rcov", ">= 0.9.8", :platform => :mri_18
  gem "childprocess", :platform => :mri
end
