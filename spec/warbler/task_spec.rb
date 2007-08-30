# (c) Copyright 2007 Nick Sieger <nicksieger@gmail.com>
# See the file LICENSES.txt included with the distribution for
# software license details.

require File.dirname(__FILE__) + '/../spec_helper'

describe Warbler::Task do
  before(:each) do
    @rake = Rake::Application.new
    Rake.application = @rake
    @config = Warbler::Config.new do |config|
      config.staging_dir = "pkg/tmp/war"
      config.war_name = "warbler"
      config.dirs = %w(bin generators lib)
      config.public_html = FileList["tasks/**/*"]
    end
  end

  def define_tasks(*tasks)
    @tasks ||= []
    tasks.each do |task|
      unless @tasks.include?(task)
        Warbler::Task.new "warble", @config, "define_#{task}_task".to_sym
        @tasks << task
      end
    end
  end

  after(:each) do
    define_tasks "clean"
    Rake::Task["warble:clean"].invoke
  end

  it "should define a clean task for removing the staging directory" do
    define_tasks "clean"
    mkdir_p @config.staging_dir
    Rake::Task["warble:clean"].invoke
    File.exist?(@config.staging_dir).should == false
  end

  it "should define a public task for copying the public files" do
    define_tasks "public"
    Rake::Task["warble:public"].invoke
    FileList["#{@config.staging_dir}/tasks/**/*"].should_not be_empty
  end
end