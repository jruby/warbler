#--
# Copyright (c) 2010 Engine Yard, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.dirname(__FILE__) + '/../spec_helper'

describe Warbler::Jar do
  before(:each) do
    @rake = Rake::Application.new
    Rake.application = @rake
    verbose(false)
    @pwd = Dir.getwd
    Dir.chdir("spec/sample_jar")
    @config = Warbler::Config.new
    @jar = Warbler::Jar.new
    @env_save = {}
    (ENV.keys.grep(/BUNDLE/) + ["RUBYOPT", "GEM_PATH"]).each {|k| @env_save[k] = ENV[k]; ENV[k] = nil}
  end

  after(:each) do
    rm_rf FileList["log", ".bundle", "tmp/war"]
    rm_f FileList["*.war", "config.ru", "*web.xml*", "config/web.xml*", "config/warble.rb",
                  "file.txt", 'manifest', 'Gemfile*', 'MANIFEST.MF*', 'init.rb*']
    Dir.chdir(@pwd)
    @env_save.keys.each {|k| ENV[k] = @env_save[k]}
  end

  def file_list(regex)
    @jar.files.keys.select {|f| f =~ regex }
  end

  it "detects a Jar trait" do
    pending
    @config.traits.should include(Warbler::Traits::Jar)
  end

  it "detects gems from the .gemspec file" do
    pending
    @jar.apply(@config)
    file_list(%r{^META-INF/gems/gems/rubyzip.*/lib/zip/zip.rb}).should_not be_empty
    file_list(%r{^META-INF/gems/specifications/rubyzip.*\.gemspec}).should_not be_empty
  end

  it "collects gem files" do
    pending
    @config.gems << "rake"
    @jar.apply(@config)
    file_list(%r{^META-INF/gems/gems/rake.*/lib/rake.rb}).should_not be_empty
    file_list(%r{^META-INF/gems/specifications/rake.*\.gemspec}).should_not be_empty
  end

  it "collects java libraries" do
    pending
    @jar.apply(@config)
    file_list(%r{^META-INF/lib/jruby-.*\.jar$}).should_not be_empty
  end

  it "collects application files" do
    pending
    @jar.apply(@config)
    file_list(%r{^sample_jar/bin$}).should_not be_empty
    file_list(%r{^sample_jar/test$}).should_not be_empty
    file_list(%r{^sample_jar/lib/sample_jar.rb$}).should_not be_empty
  end

  it "adds a Main class" do
    pending
    @jar.apply(@config)
    file_list(%r{^Main\.class$}).should_not be_empty
  end

  it "adds an init.rb" do
    pending
    @jar.apply(@config)
    file_list(%r{^META-INF/init.rb$}).should_not be_empty
  end

  it "adds a main.rb" do
    pending
    @jar.apply(@config)
    file_list(%r{^META-INF/main.rb$}).should_not be_empty
  end

  it "accepts a custom manifest file" do
    pending
    touch 'manifest'
    @config.manifest_file = 'manifest'
    @jar.apply(@config)
    @jar.files['META-INF/MANIFEST.MF'].should == "manifest"
  end

  it "accepts a MANIFEST.MF file if it exists in the project root" do
    pending
    touch 'MANIFEST.MF'
    @jar.apply(@config)
    @jar.files['META-INF/MANIFEST.MF'].should == "MANIFEST.MF"
  end

  it "does not add a manifest if one already exists" do
    pending
    @jar.files['META-INF/MANIFEST.MF'] = 'manifest'
    @jar.add_manifest(@config)
    @jar.files['META-INF/MANIFEST.MF'].should == "manifest"
  end
end

