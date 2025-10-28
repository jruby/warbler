#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

module Warbler
  # A set of gems. This only exists to allow expected operations
  # to be used to add gems, and for backwards compatibility.
  # It would be easier to just use a hash.
  class Gems < Hash
    ANY_VERSION = nil
    private_constant :ANY_VERSION

    def initialize(gems = nil)
      if gems.is_a?(Hash)
        self.merge!(gems)
      elsif gems.is_a?(Array)
        gems.each {|gem| self << gem }
      end
    end

    def <<(gem)
      @specs = nil
      self[gem] ||= ANY_VERSION
    end

    def +(other)
      @specs = nil
      other.each {|g| self[g] ||= ANY_VERSION }
      self
    end

    def -(other)
      @specs = nil
      other.each {|g| self.delete(g)}
      self
    end

    def full_name_for(name, gem_dependencies)
      gem_spec = specs(gem_dependencies).detect{ |spec| spec.name == name }
      gem_spec.nil? ? name : gem_spec.full_name
    end

    def specs(gem_dependencies)
      @specs ||= map { |gem, version| find_single_gem_files(gem_dependencies, gem, version) }.flatten.compact
    end

  private

    # Add a single gem to WEB-INF/gems
    def find_single_gem_files(gem_dependencies, gem_pattern, version = nil)
      case gem_pattern
      when Gem::Specification
        return BundlerHelper.to_spec(gem_pattern)
      when Gem::Dependency
        gem = gem_pattern
      else
        gem = Gem::Dependency.new(gem_pattern, Gem::Requirement.create(version))
      end
      # skip development dependencies
      return nil if gem.type != :runtime

      spec = gem.to_spec
      return spec unless gem_dependencies
      [spec] + spec.dependencies.map { |dependent_gem| find_single_gem_files(gem_dependencies, dependent_gem) }
    end

  end
end
