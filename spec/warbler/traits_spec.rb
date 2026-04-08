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

  describe "conflicts" do
    it "Jar conflicts with War" do
      expect(Warbler::Traits::Jar.conflicts).to include(Warbler::Traits::War)
    end

    it "War conflicts with Jar" do
      expect(Warbler::Traits::War.conflicts).to include(Warbler::Traits::Jar)
    end

    it "traits with no declared conflicts return an empty array" do
      expect(Warbler::Traits::Bundler.conflicts).to eq([])
    end
  end

  describe "forced_traits" do
    context "in a Rack project with Bundler" do
      run_in_directory 'spec/sample_bundler'

      it "auto-detects War trait by default" do
        config = Warbler::Config.new
        expect(config.traits).to include(Warbler::Traits::War)
        expect(config.traits).to include(Warbler::Traits::Rack)
        expect(config.traits).to_not include(Warbler::Traits::Jar)
      end

      it "forces Jar and excludes War when Jar is forced" do
        config = Warbler::Config.new(forced_traits: [Warbler::Traits::Jar])
        expect(config.traits).to include(Warbler::Traits::Jar)
        expect(config.traits).to_not include(Warbler::Traits::War)
      end

      it "excludes traits that require an excluded trait" do
        config = Warbler::Config.new(forced_traits: [Warbler::Traits::Jar])
        expect(config.traits).to_not include(Warbler::Traits::Rack)
      end

      it "preserves non-conflicting auto-detected traits" do
        config = Warbler::Config.new(forced_traits: [Warbler::Traits::Jar])
        expect(config.traits).to include(Warbler::Traits::Bundler)
      end

      it "runs before_configure with forced traits" do
        config = Warbler::Config.new(forced_traits: [Warbler::Traits::Jar])
        expect(config.jar_extension).to eq('jar')
      end
    end

    context "with no forced traits" do
      run_in_directory 'spec/sample_jar'

      it "behaves identically to auto-detection" do
        default_config = Warbler::Config.new
        forced_config = Warbler::Config.new(forced_traits: [])
        expect(forced_config.traits).to eq(default_config.traits)
      end
    end
  end
end
