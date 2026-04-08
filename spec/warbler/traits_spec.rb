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
        expect(result.index(requirement)).to be <= result.index(trait)
      end
    end
  end

  describe "#auto_detect_traits" do
    context "in a Rack project with Bundler" do
      run_in_directory 'spec/sample_bundler'

      it "auto-detects traits" do
        config = Warbler::Config.new
        expect(config.traits).to eq([Warbler::Traits::War, Warbler::Traits::Rack, Warbler::Traits::Bundler])
      end
    end
  end

  describe "forced_traits" do
    context "with no forced traits" do
      run_in_directory 'spec/sample_jar'

      it "behaves identically to auto-detection" do
        default_config = Warbler::Config.new
        forced_config = Warbler::Config.new(forced_traits: [])
        expect(forced_config.traits).to eq(default_config.traits)
      end
    end

    context "in a Rack project with Bundler with Jar forced" do
      run_in_directory 'spec/sample_bundler'

      it "only has the Jar trait" do
        config = Warbler::Config.new(forced_traits: [Warbler::Traits::Jar])
        expect(config.traits).to eq([Warbler::Traits::Jar])
      end
    end
  end
end
