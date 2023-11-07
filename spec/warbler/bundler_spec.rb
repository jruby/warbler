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
    `cd #{Dir.pwd} && #{RUBY_EXE} -S bundle _#{::Bundler::VERSION}_ install #{args.join(' ')}`
  end

  let(:config) { drbclient.config(@extra_config) }
  let(:jar) { drbclient.jar }

  context "in a war project" do
    run_in_directory "spec/sample_war"
    cleanup_temp_files

    before :each do
      File.open("Gemfile", "w") {|f| f << "source 'https://rubygems.org'\ngem 'rspec'"}
    end

    it "detects a Bundler trait" do
      expect(config.traits).to include(Warbler::Traits::Bundler)
    end

    it "detects a Gemfile and process only its gems" do
      use_config do |config|
        config.gems << "rake"
      end
      jar.apply(config)
      expect(file_list(%r{WEB-INF/Gemfile})).to_not be_empty
      expect(file_list(%r{WEB-INF/gems/specifications/rspec})).to_not be_empty
      expect(file_list(%r{WEB-INF/gems/specifications/rake})).to be_empty
    end

    it "copies Gemfiles into the war" do
      File.open("Gemfile.lock", "w") {|f| f << "GEM"}
      jar.apply(config)
      expect(file_list(%r{WEB-INF/Gemfile})).to_not be_empty
      expect(file_list(%r{WEB-INF/Gemfile.lock})).to_not be_empty
    end

    it "allows overriding of the gem path when using Bundler" do
      use_config do |config|
        config.gem_path = '/WEB-INF/jewels'
      end
      jar.apply(config)
      expect(file_list(%r{WEB-INF/jewels/specifications/rspec})).to_not be_empty
    end

    context 'with :git entries in the Gemfile' do
      create_git_gem("tester")

      it "works with :git entries in Gemfiles" do
        File.open("Gemfile", "w") {|f| f << "source 'file://#{@gem_dir}'\ngem 'tester', :git => '#{@gem_dir}'\n"}
        bundle_install '--local'
        jar.apply(config)
        expect(file_list(%r{WEB-INF/gems/bundler/gems/tester[^/]*/lib/tester/version\.rb})).to_not be_empty
        expect(file_list(%r{WEB-INF/gems/bundler/gems/tester[^/]*/tester.gemspec})).to_not be_empty
      end

      it "bundles only the gemspec for :git entries that are excluded" do
        File.open("Gemfile", "w") {|f| f << "source 'https://rubygems.org'\ngem 'rake'\ngroup :test do\ngem 'tester', :git => '#{@gem_dir}'\nend\n"}
        bundle_install '--local'
        jar.apply(config)
        expect(file_list(%r{WEB-INF/gems/bundler/gems/tester[^/]*/lib/tester/version\.rb})).to be_empty
        expect(file_list(%r{WEB-INF/gems/bundler/gems/tester[^/]*/tester.gemspec})).to_not be_empty
      end

    end

    context 'with :path entries in the Gemfile' do

      after { FileUtils.rm_r(@gem_dir) rescue nil if @gem_dir }

      it "does not work with absolute :path" do
        @gem_dir = generate_gem('tester', Dir.mktmpdir("gems-#{Time.now.to_i}"))
        File.open("Gemfile", "w") {|f| f << "source 'file://#{@gem_dir}'\ngem 'tester', :path => '#{@gem_dir}'\n"}
        bundle_install '--local'
        silence { jar.apply(config) }
        expect(file_list(%r{tester})).to be_empty
      end

      it "does work with relative :path" do
        gem_dir = File.join(Dir.pwd, 'gems/tester')
        #begin
          Dir.mkdir(gem_dir)
          @gem_dir = generate_gem('tester', 'gems/tester') # spec/sample_war/gems
          File.open("Gemfile", "w") {|f| f << "source 'https://rubygems.org'\ngem 'rake'\ngem 'tester', :path => 'gems/tester'\n"}
          bundle_install '--local'
          jar.apply(config)
          expect(file_list(%r{tester})).to_not be_empty # included from :path as is
          expect(file_list(%r{WEB-INF/gems/bundler/gems/tester[^/]*/lib/tester/version\.rb})).to be_empty
          expect(file_list(%r{WEB-INF/gems/bundler/gems/tester[^/]*/tester.gemspec})).to be_empty
        #ensure
          #FileUtils.rm_r(gem_dir) rescue nil
        #end
      end

    end

    it "does not bundle dependencies in the test group by default" do
      File.open("Gemfile", "w") {|f| f << "source 'https://rubygems.org'\ngem 'rake'\ngroup :test do\ngem 'rspec'\nend\n"}
      jar.apply(config)
      expect(file_list(%r{WEB-INF/gems/gems/rake[^/]*/})).to_not be_empty
      expect(file_list(%r{WEB-INF/gems/gems/rspec[^/]*/})).to be_empty
      expect(file_list(%r{WEB-INF/gems/specifications/rake})).to_not be_empty
      expect(file_list(%r{WEB-INF/gems/specifications/rspec})).to be_empty
    end

    it "adds BUNDLE_WITHOUT to init.rb" do
      jar.add_init_file(config)
      contents = jar.contents('META-INF/init.rb')
      expect(contents).to match /ENV\['BUNDLE_WITHOUT'\]/
      expect(contents).to match /'development:test:assets'/
    end

    it "adds BUNDLE_GEMFILE to init.rb" do
      jar.add_init_file(config)
      contents = jar.contents('META-INF/init.rb')
      expect(contents).to match Regexp.new(Regexp.quote("ENV['BUNDLE_GEMFILE'] ||= $servlet_context.getRealPath('/WEB-INF/Gemfile')"))
    end

    it "uses ENV['BUNDLE_GEMFILE'] if set" do
      mv "Gemfile", "Special-Gemfile"
      ENV['BUNDLE_GEMFILE'] = "Special-Gemfile"
      expect(config.traits).to include(Warbler::Traits::Bundler)
    end
  end

  context "in a jar project" do
    run_in_directory "spec/sample_jar"
    cleanup_temp_files

    context 'with :git entries in the Gemfile' do
      create_git_gem("tester")

      it "works with :git entries in Gemfiles" do
        File.open("Gemfile", "w") {|f| f << "source 'file://#{@gem_dir}'\ngem 'tester', :git => '#{@gem_dir}'\n"}
        bundle_install '--local'
        jar.apply(config)
        expect(file_list(%r{^bundler/gems/tester[^/]*/lib/tester/version\.rb})).to_not be_empty
        expect(file_list(%r{^bundler/gems/tester[^/]*/tester.gemspec})).to_not be_empty
        jar.add_init_file(config)
        contents = jar.contents('META-INF/init.rb')
        expect(contents).to match /ENV\['BUNDLE_GEMFILE'\] = File.expand_path(.*, __FILE__)/
      end
    end

    it "adds BUNDLE_GEMFILE to init.rb" do
      File.open("Gemfile", "w") {|f| f << "source 'https://rubygems.org/'" }
      jar.add_init_file(config)
      contents = jar.contents('META-INF/init.rb')
      expect(contents).to match /ENV\['BUNDLE_GEMFILE'\] = File.expand_path(.*, __FILE__)/
    end
  end

  context "when frozen" do
    run_in_directory "spec/sample_bundler"

    it "includes the bundler gem" do
      bundle_install
      jar.apply(config)
      expect(config.gems.detect{|k,v| k.name == 'bundler'}).to_not be nil
      expect(file_list(/bundler-/)).to_not be_empty
    end

    it "does not include the bundler cache directory" do
      jar.apply(config)
      expect(file_list(%r{vendor/bundle})).to be_empty
    end

    it "includes ENV['BUNDLE_FROZEN'] in init.rb" do
      jar.apply(config)
      contents = jar.contents('META-INF/init.rb')
      expect(contents.split("\n").grep(/ENV\['BUNDLE_FROZEN'\] = '1'/)).to_not be_empty
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
        expect(file_list(%r{^WarMain\.class$})).to_not be_empty
        expect(file_list(%r{^JarMain\.class$})).to_not be_empty
      end

      it "can run commands in the generated warfile" do
        jar.create('foo.war')
        stdin, stdout, stderr, wait_thr = Open3.popen3('java -jar foo.war -S rake test_task')
        expect(wait_thr.value.success?).to be(true)
        expect(stderr.readlines.join).to eq("")
        expect(stdout.readlines.join).to eq("success\n")
      end
    end
  end

  context "when deployment" do
    run_in_directory "spec/sample_bundler"

    it "includes the bundler gem" do
      bundle_install '--deployment'
      jar.apply(config)
      expect(file_list(%r{gems/rake-12.3.3/lib})).to_not be_empty
      expect(file_list(%r{gems/bundler-})).to_not be_empty
      expect(file_list(%r{gems/bundler-.*/lib})).to_not be_empty
    end
  end

  context "in a rack app" do
    run_in_directory "spec/sample_rack_war"
    cleanup_temp_files except: '**/config.ru'

    it "should have default load path" do
      jar.add_init_file(config)
      contents = jar.contents('META-INF/init.rb')
      expect(contents).to match /\$LOAD_PATH\.unshift \$servlet_context\.getRealPath\('\/WEB-INF'\) if \$servlet_context/
    end
  end
end
