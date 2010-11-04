module Warbler
  # Traits are project configuration characteristics that correspond
  # to the framework or project layout. Each trait corresponds to a
  # class in Warbler::Traits that contains baked-in knowledge about
  # the kind of project and how it should be packed into the jar or
  # war file.
  module Traits
  end
end

require 'warbler/traits/war'
require 'warbler/traits/rails'
require 'warbler/traits/merb'
require 'warbler/traits/rack'
require 'warbler/traits/bundler'
