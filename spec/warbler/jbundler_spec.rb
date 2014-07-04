#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.expand_path('../../spec_helper', __FILE__)

describe Warbler::Jar, "with JBundler" do
  use_fresh_rake_application
  use_fresh_environment
  run_out_of_process_with_drb

  def file_list(regex)
    jar.files.keys.select {|f| f =~ regex }
  end

  def use_config(&block)
    @extra_config = block
  end

  let(:config) { drbclient.config(@extra_config) }
  let(:jar) { drbclient.jar }

  context "in a war project" do
    run_in_directory "spec/sample_war"
    cleanup_temp_files

    before :each do
      File.open("Gemfile", "w") {|f| f << "gem 'jbundler'"}
      File.open("Jarfile", "w") {|f| f << "jar 'org.slf4j:slf4j-simple', '1.7.5'"}
    end

    it "detects a JBundler trait" do
      config.traits.should include(Warbler::Traits::JBundler)
    end

    it "detects a Jarfile and process only its jars" do
      use_config do |config|
        config.java_libs << "local.jar"
      end
      jar.apply(config)
      file_list(%r{WEB-INF/libs/local.jar}).should be_empty
    end

    it "copies jars from jbundler classpath into the war" do
      File.open(".jbundler/classpath.rb", "w") {|f| f << "JBUNDLER_CLASSPATH = ['some.jar']"}
      File.open("some.jar", "w") {|f| f << ""}
      jar.apply(config)
      file_list(%r{WEB-INF/lib/some.jar}).should_not be_empty
    end

    it "adds JBUNDLE_SKIP to init.rb" do
      jar.add_init_file(config)
      contents = jar.contents('META-INF/init.rb')
      contents.should =~ /ENV\['JBUNDLE_SKIP'\] = 'true'/
    end

    it "uses ENV['JBUNDLE_JARFILE'] if set" do
      mv "Jarfile", "Special-Jarfile"
      ENV['JBUNDLE_JARFILE'] = "Special-Jarfile"
      config.traits.should include(Warbler::Traits::JBundler)
    end
  end

  context "when locked down" do
    run_in_directory "spec/sample_jbundler"

    it "does not include the jbundler gem (as it is in the development group)" do
      pending( "needs JRuby to work" ) unless defined? JRUBY_VERSION
      jar.apply(config)
      config.gems.detect{|k,v| k.name == 'jbundler'}.should be nil
      file_list(/jbundler-/).should be_empty
    end

    it "does not include the jbundler runtime config" do
      pending( "needs JRuby to work" ) unless defined? JRUBY_VERSION
      jar.apply(config)
      file_list(%r{WEB-INF/.jbundler}).should be_empty
    end
  end
end
