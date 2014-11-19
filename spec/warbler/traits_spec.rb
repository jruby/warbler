#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.expand_path('../../spec_helper', __FILE__)

describe Warbler::Traits do
  it "are ordered by fewer dependencies first" do
    traits = Warbler::TraitsDependencyArray.new( Warbler::Traits.constants.map {|t| Warbler::Traits.const_get(t)})
    result = traits.shuffle!.tsort

    result.each do |trait|
      trait.requirements.each do |requirement|
        result.index(requirement).should < result.index(trait)
      end
    end
  end
end
