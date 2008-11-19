#--
# (c) Copyright 2007-2008 Sun Microsystems, Inc.
# See the file LICENSES.txt included with the distribution for
# software license details.
#++

module Warbler
  # A set of gems. This only exists to allow expected operations
  # to be used to add gems, and for backwards compatibility.
  # It would be easier to just use a hash.
  class Gems < Hash
    ANY_VERSION = nil
    
    def initialize(gems = nil)
      if gems.is_a?(Hash)
        self.merge!(gems)
      elsif gems.is_a?(Array)
        gems.each {|gem| self << gem }
      end
    end
    
    def <<(gem)
      self[gem] ||= ANY_VERSION
    end

    def +(other)
      other.each {|g| self[g] ||= ANY_VERSION }
      self
    end

    def -(other)
      other.each {|g| self.delete(g)}
      self
    end
  end
end
