#!/usr/bin/env ruby

if RUBY_VERSION =~ /^1.8/
  APP_PATH = File.expand_path('../../config/application',  __FILE__)
  require File.expand_path('../../config/boot',  __FILE__)
  require 'rails/commands' 
else
  APP_PATH = File.expand_path('../../config/application',  __FILE__)
  require_relative '../config/boot'
  require 'rails/commands'
end
