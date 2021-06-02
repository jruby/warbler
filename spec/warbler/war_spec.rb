#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.expand_path('../../spec_helper', __FILE__)

describe Warbler::War do
  it "is deprecated, replace occurrences with Warbler::Jar" do
    expect(capture { Warbler::War.new }).to match /deprecated/
  end
end
