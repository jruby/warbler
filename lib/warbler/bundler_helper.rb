#--
# Copyright (c) 2014-2015 JRuby Team
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

module Warbler
  module BundlerHelper
    def to_spec(spec)
      spec.respond_to?(:to_spec) ? spec.to_spec : spec
    end
    module_function :to_spec
  end
end

