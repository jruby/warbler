#--
# Copyright (c) 2010 Engine Yard, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

module Warbler
  module Traits
    class Gemspec
      include Trait

      def self.detect?
        !Dir['*.gemspec'].empty?
      end
    end
  end
end
