require 'warbler/jar'

module Warbler
  class War < Jar
    alias create_war create_jar
  end
end
