#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.expand_path('../../spec_helper', __FILE__)
require 'open3'

describe Warbler::Jar, "with Bundler" do
  use_fresh_rake_application
  use_fresh_environment
  run_out_of_process_with_drb

  def file_list(regex)
    jar.files.keys.select {|f| f =~ regex }
  end

  def use_config(&block)
    @extra_config = block
  end

  def bundle_install(*args)
    `cd #{Dir.pwd} && #{RUBY_EXE} -S bundle install #{args.join(' ')}`
  end

  let(:config) { drbclient.config(@extra_config) }
  let(:jar) { drbclient.jar }

  context "in a war project" do
    run_in_directory "spec/sample_war"
    cleanup_temp_files

    before :each do
      File.open("Gemfile", "w") {|f| f << "gem 'rspec'"}
    end

    it "detects a Bundler trait" do
      config.traits.should include(Warbler::Traits::Bundler)
    end

    it "detects a Gemfile and process only its gems" do
      use_config do |config|
        config.gems << "rake"
      end
      jar.apply(config)
      file_list(%r{WEB-INF/Gemfile}).should_not be_empty
      file_list(%r{WEB-INF/gems/specifications/rspec}).should_not be_empty
      file_list(%r{WEB-INF/gems/specifications/rake}).should be_empty
    end

    it "copies Gemfiles into the war" do
      File.open("Gemfile.lock", "w") {|f| f << "GEM"}
      jar.apply(config)
      file_list(%r{WEB-INF/Gemfile}).should_not be_empty
      file_list(%r{WEB-INF/Gemfile.lock}).should_not be_empty
    end

    it "allows overriding of the gem path when using Bundler" do
      use_config do |config|
        config.gem_path = '/WEB-INF/jewels'
      end
      jar.apply(config)
      file_list(%r{WEB-INF/jewels/specifications/rspec}).should_not be_empty
    end

    context 'with :git entries in the Gemfile' do
      create_git_gem("tester")

      it "works with :git entries in Gemfiles" do
        File.open("Gemfile", "w") {|f| f << "gem 'tester', :git => '#{@gem_dir}'\n"}
        bundle_install '--local'
        jar.apply(config)
        file_list(%r{WEB-INF/gems/bundler/gems/tester[^/]*/lib/tester/version\.rb}).should_not be_empty
        file_list(%r{WEB-INF/gems/bundler/gems/tester[^/]*/tester.gemspec}).should_not be_empty
      end

      it "bundles only the gemspec for :git entries that are excluded" do
        File.open("Gemfile", "w") {|f| f << "gem 'rake'\ngroup :test do\ngem 'tester', :git => '#{@gem_dir}'\nend\n"}
        bundle_install '--local'
        jar.apply(config)
        file_list(%r{WEB-INF/gems/bundler/gems/tester[^/]*/lib/tester/version\.rb}).should be_empty
        file_list(%r{WEB-INF/gems/bundler/gems/tester[^/]*/tester.gemspec}).should_not be_empty
      end

      it "does not work with :path entries in Gemfiles" do
        File.open("Gemfile", "w") {|f| f << "gem 'tester', :path => '#{@gem_dir}'\n"}
        bundle_install '--local'
        silence { jar.apply(config) }
        file_list(%r{tester}).should be_empty
      end
    end

    it "does not bundle dependencies in the test group by default" do
      File.open("Gemfile", "w") {|f| f << "gem 'rake'\ngroup :test do\ngem 'rspec'\nend\n"}
      jar.apply(config)
      file_list(%r{WEB-INF/gems/gems/rake[^/]*/}).should_not be_empty
      file_list(%r{WEB-INF/gems/gems/rspec[^/]*/}).should be_empty
      file_list(%r{WEB-INF/gems/specifications/rake}).should_not be_empty
      file_list(%r{WEB-INF/gems/specifications/rspec}).should be_empty
    end

    it "adds BUNDLE_WITHOUT to init.rb" do
      jar.add_init_file(config)
      contents = jar.contents('META-INF/init.rb')
      contents.should =~ /ENV\['BUNDLE_WITHOUT'\]/
      contents.should =~ /'development:test:assets'/
    end

    it "adds BUNDLE_GEMFILE to init.rb" do
      jar.add_init_file(config)
      contents = jar.contents('META-INF/init.rb')
      contents.should =~ Regexp.new(Regexp.quote("ENV['BUNDLE_GEMFILE'] ||= $servlet_context.getRealPath('/WEB-INF/Gemfile')"))
    end

    it "uses ENV['BUNDLE_GEMFILE'] if set" do
      mv "Gemfile", "Special-Gemfile"
      ENV['BUNDLE_GEMFILE'] = "Special-Gemfile"
      config.traits.should include(Warbler::Traits::Bundler)
    end
  end

  context "in a jar project" do
    run_in_directory "spec/sample_jar"
    cleanup_temp_files

    context 'with :git entries in the Gemfile' do
      create_git_gem("tester")

      it "works with :git entries in Gemfiles" do
        File.open("Gemfile", "w") {|f| f << "gem 'tester', :git => '#{@gem_dir}'\n"}
        bundle_install '--local'
        jar.apply(config)
        file_list(%r{^bundler/gems/tester[^/]*/lib/tester/version\.rb}).should_not be_empty
        file_list(%r{^bundler/gems/tester[^/]*/tester.gemspec}).should_not be_empty
        jar.add_init_file(config)
        contents = jar.contents('META-INF/init.rb')
        contents.should =~ /ENV\['BUNDLE_GEMFILE'\] = File.expand_path(.*, __FILE__)/
      end
    end

    it "adds BUNDLE_GEMFILE to init.rb" do
      File.open("Gemfile", "w") {|f| f << "source 'http://rubygems.org/'" }
      jar.add_init_file(config)
      contents = jar.contents('META-INF/init.rb')
      contents.should =~ /ENV\['BUNDLE_GEMFILE'\] = File.expand_path(.*, __FILE__)/
    end
  end

  context "when frozen" do
    run_in_directory "spec/sample_bundler"

    it "includes the bundler gem" do
      jar.apply(config)
      config.gems.detect{|k,v| k.name == 'bundler'}.should_not be nil
      file_list(/bundler-/).should_not be_empty
    end

    it "does not include the bundler cache directory" do
      jar.apply(config)
      file_list(%r{vendor/bundle}).should be_empty
    end

    it "includes ENV['BUNDLE_FROZEN'] in init.rb" do
      jar.apply(config)
      contents = jar.contents('META-INF/init.rb')
      contents.split("\n").grep(/ENV\['BUNDLE_FROZEN'\] = '1'/).should_not be_empty
    end

    context "with the runnable feature" do
      before do
        File.open("Rakefile", "w") do |f|
          f << <<-RUBY
          task :test_task do
            puts "success"
          end
          RUBY
        end

        use_config do |config|
          config.features = %w{runnable}
        end
        jar.apply(config)
      end

      after do
        rm_rf "Rakefile"
        rm_rf "foo.war"
      end

      it "adds WarMain and JarMain to file" do
        file_list(%r{^WarMain\.class$}).should_not be_empty
        file_list(%r{^JarMain\.class$}).should_not be_empty
      end

      it "can run commands in the generated warfile" do
        jar.create('foo.war')
        if RUBY_VERSION >= '1.9'
          stdin, stdout, stderr, wait_thr = Open3.popen3('java -jar foo.war -S rake test_task')
          wait_thr.value.success?.should be(true)

          # TODO need to update rake or we'll get an warning in stderr
          # stderr.readlines.join.should eq("")
          stdout.readlines.join.should include("success\n")
        else
          `java -jar foo.war -S rake -T`
          $?.exitstatus.should == 0
        end
      end
    end
  end

  context "when deployment" do
    run_in_directory "spec/sample_bundler"

    it "includes the bundler gem" do
      bundle_install '--deployment'
      jar.apply(config)
      file_list(%r{gems/rake-0.8.7/lib}).should_not be_empty
      file_list(%r{gems/bundler-}).should_not be_empty
      file_list(%r{gems/bundler-.*/lib}).should_not be_empty
    end
  end

  context "in a rack app" do
    run_in_directory "spec/sample_rack_war"
    cleanup_temp_files '**/config.ru'

    it "should have default load path" do
      jar.add_init_file(config)
      contents = jar.contents('META-INF/init.rb')
      contents.should =~ /\$LOAD_PATH\.unshift \$servlet_context\.getRealPath\('\/WEB-INF'\) if \$servlet_context/
    end
  end
end
