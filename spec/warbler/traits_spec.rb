#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.expand_path('../../spec_helper', __FILE__)

describe Warbler::Traits do
  it "are ordered by fewer dependencies first" do
    traits = [Warbler::Traits::War, Warbler::Traits::Bundler, Warbler::Traits::Rails]
    result = traits.shuffle.sort
    result.index(Warbler::Traits::War).should < result.index(Warbler::Traits::Bundler)
    result.index(Warbler::Traits::War).should < result.index(Warbler::Traits::Rails)
  end
end
