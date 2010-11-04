require 'warbler/jar'

module Warbler
  # Warbler::War is Deprecated. Please use Warbler::Jar.
  class War < Jar
    def initialize(*)
      super
      warn "Warbler::War is deprecated. Please replace all occurrences with Warbler::Jar."
    end
  end
end
