#--
# Copyright (c) 2014-2015 JRuby Team
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

module Warbler
  module BundlerHelper
    def to_spec(spec)
      # JRuby <= 1.7.20 does not handle respond_to? with method_missing right
      # thus a `spec.respond_to?(:to_spec) ? spec.to_spec : spec` won't do :
      if ::Bundler.const_defined?(:StubSpecification) # since Bundler 1.10.1
        spec = spec.to_spec if spec.is_a?(::Bundler::StubSpecification)
      else
        spec = spec.to_spec if spec.respond_to?(:to_spec)
      end
      spec
    end
    module_function :to_spec
  end
end

