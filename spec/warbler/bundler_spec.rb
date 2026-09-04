#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.expand_path('../../spec_helper', __FILE__)
require 'open3'
require 'bundler'
require 'yaml'

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

  def bundle(*args)
    `cd #{Dir.pwd} && #{RUBY_EXE} -S bundle _#{::Bundler::VERSION}_ #{args.join(' ')}`
  end

  def bundle_install(*args)
    bundle('install', *args)
  end

  let(:config) { drbclient.config(@extra_config) }
  let(:jar) { drbclient.jar }

  def apply_silently
    silence { jar.apply(config) }
  end

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
      apply_silently
      expect(file_list(%r{WEB-INF/Gemfile})).to_not be_empty
      expect(file_list(%r{WEB-INF/gems/specifications/rspec})).to_not be_empty
      expect(file_list(%r{WEB-INF/gems/specifications/rake})).to be_empty
    end

    it "copies Gemfiles into the war" do
      File.open("Gemfile.lock", "w") {|f| f << "GEM"}
      apply_silently
      expect(file_list(%r{WEB-INF/Gemfile})).to_not be_empty
      expect(file_list(%r{WEB-INF/Gemfile.lock})).to_not be_empty
    end

    it "generates an opinionated .bundle/config into the war" do
      File.open("Gemfile.lock", "w") {|f| f << "GEM"}
      apply_silently
      expect(file_list(%r{WEB-INF/\.bundle/config})).to_not be_empty
      settings = YAML.load(jar.files['WEB-INF/.bundle/config'].string)
      expect(settings['BUNDLE_VERSION']).to eq 'system'
      expect(settings['BUNDLE_FROZEN']).to eq 'true'
      expect(settings['BUNDLE_PATH__SYSTEM']).to eq 'true'
      expect(settings['BUNDLE_AUTO_INSTALL']).to eq 'false'
    end

    it "does not force BUNDLE_FROZEN without a Gemfile.lock" do
      apply_silently
      settings = YAML.load(jar.files['WEB-INF/.bundle/config'].string)
      expect(settings).to_not have_key 'BUNDLE_FROZEN'
      expect(settings['BUNDLE_VERSION']).to eq 'system'
    end

    it "does not force BUNDLE_FROZEN when opted out via config.bundler[:frozen]" do
      File.open("Gemfile.lock", "w") {|f| f << "GEM"}
      use_config do |config|
        config.bundler = { :frozen => false }
      end
      apply_silently
      settings = YAML.load(jar.files['WEB-INF/.bundle/config'].string)
      expect(settings).to_not have_key 'BUNDLE_FROZEN'
      expect(settings['BUNDLE_VERSION']).to eq 'system' # other deployment settings unaffected
    end

    context "with an application-provided .bundle/config" do
      before :each do
        FileUtils.mkdir_p('.bundle')
        File.write File.join('.bundle', 'config'), <<-CONFIG.gsub(/^ {10}/, '')
          ---
          BUNDLE_RETRY: "5"
          BUNDLE_VERSION: "lockfile"
          BUNDLE_GITHUB__COM: "user:secret"
        CONFIG
      end

      after(:each) { FileUtils.rm_rf('.bundle') }

      it "does not carry any of it into the archive (only warbler's deployment settings)" do
        File.open("Gemfile.lock", "w") {|f| f << "GEM"}
        apply_silently
        settings = YAML.load(jar.files['WEB-INF/.bundle/config'].string)
        expect(settings).to_not have_key 'BUNDLE_RETRY'
        expect(settings).to_not have_key 'BUNDLE_GITHUB__COM' # credentials never packed
        expect(settings['BUNDLE_VERSION']).to eq 'system'
        expect(settings.keys).to match_array %w(BUNDLE_VERSION BUNDLE_FROZEN BUNDLE_PATH__SYSTEM BUNDLE_AUTO_INSTALL)
      end
    end

    it "does not package default gems (provided by the JRuby runtime)" do
      File.open("Gemfile", "w") {|f| f << "source 'https://rubygems.org'\ngem 'rspec'\ngem 'stringio'"}
      apply_silently
      expect(file_list(%r{WEB-INF/gems/specifications/rspec})).to_not be_empty
      expect(file_list(%r{WEB-INF/gems/specifications/stringio})).to be_empty
      expect(file_list(%r{WEB-INF/gems/gems/stringio})).to be_empty
    end

    it "allows overriding of the gem path when using Bundler" do
      use_config do |config|
        config.gem_path = '/WEB-INF/jewels'
      end
      apply_silently
      expect(file_list(%r{WEB-INF/jewels/specifications/rspec})).to_not be_empty
    end

    context 'with :git entries in the Gemfile' do
      create_git_gem("tester")

      it "works with :git entries in Gemfiles" do
        File.open("Gemfile", "w") {|f| f << "source 'file://#{@gem_dir}'\ngem 'tester', :git => '#{@gem_dir}'\n"}
        bundle_install '--local'
        apply_silently
        expect(file_list(%r{WEB-INF/gems/bundler/gems/tester[^/]*/lib/tester/version\.rb})).to_not be_empty
        expect(file_list(%r{WEB-INF/gems/bundler/gems/tester[^/]*/tester.gemspec})).to_not be_empty
      end

      it "respects config.gem_excludes for :git entries" do
        File.open("Gemfile", "w") {|f| f << "source 'file://#{@gem_dir}'\ngem 'tester', :git => '#{@gem_dir}'\n"}
        bundle_install '--local'
        use_config do |config|
          config.gem_excludes += [%r{^lib/tester/version}]
        end
        apply_silently
        expect(file_list(%r{WEB-INF/gems/bundler/gems/tester[^/]*/lib/tester/version\.rb})).to be_empty
        expect(file_list(%r{WEB-INF/gems/bundler/gems/tester[^/]*/tester.gemspec})).to_not be_empty
      end

      it "does not bundle :git entries that are excluded" do
        File.open("Gemfile", "w") {|f| f << "source 'https://rubygems.org'\ngem 'rake'\ngroup :test do\ngem 'tester', :git => '#{@gem_dir}'\nend\n"}
        bundle_install '--local'
        apply_silently
        # bundler (>= 2.6) does not need excluded git sources present at all
        expect(file_list(%r{WEB-INF/gems/bundler/gems/tester})).to be_empty
      end

    end

    context 'with :path entries in the Gemfile' do

      after { FileUtils.rm_r(@gem_dir) rescue nil if @gem_dir }

      it "does not work with absolute :path" do
        @gem_dir = generate_gem('tester', Dir.mktmpdir("gems-#{Time.now.to_i}"))
        File.open("Gemfile", "w") {|f| f << "source 'file://#{@gem_dir}'\ngem 'tester', :path => '#{@gem_dir}'\n"}
        bundle_install '--local'
        apply_silently
        expect(file_list(%r{tester})).to be_empty
      end

      it "does work with relative :path, packed once at its relative location" do
        gem_dir = File.join(Dir.pwd, 'gems/tester')
        #begin
          Dir.mkdir(gem_dir)
          @gem_dir = generate_gem('tester', 'gems/tester') # spec/sample_war/gems
          File.open("Gemfile", "w") {|f| f << "source 'https://rubygems.org'\ngem 'rake'\ngem 'tester', :path => 'gems/tester'\n"}
          bundle_install '--local'
          apply_silently
          # packed at the Gemfile-relative location bundler resolves at runtime
          expect(file_list(%r{WEB-INF/gems/tester/tester\.gemspec})).to_not be_empty
          expect(file_list(%r{WEB-INF/gems/tester/lib/tester/version\.rb})).to_not be_empty
          # and nowhere else (#465): not in the gem repository nor as a git checkout
          expect(file_list(%r{WEB-INF/gems/gems/tester})).to be_empty
          expect(file_list(%r{WEB-INF/gems/specifications/tester})).to be_empty
          expect(file_list(%r{WEB-INF/gems/bundler/gems/tester})).to be_empty
        #ensure
          #FileUtils.rm_r(gem_dir) rescue nil
        #end
      end

    end

    it "does not bundle dependencies in the test group by default" do
      File.open("Gemfile", "w") {|f| f << "source 'https://rubygems.org'\ngem 'rake'\ngroup :test do\ngem 'rspec'\nend\n"}
      apply_silently
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
        apply_silently
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

    it "does not vendor the (default gem) bundler - the packed JRuby provides it" do
      bundle_install
      apply_silently
      expect(config.gems.detect{|k,v| k.name == 'bundler'}).to be nil
      expect(file_list(%r{gems/bundler-})).to be_empty
      expect(file_list(%r{specifications/bundler-})).to be_empty
    end

    it "does not include the bundler cache directory" do
      apply_silently
      expect(file_list(%r{vendor/bundle})).to be_empty
    end

    it "carries the frozen setting into the packed .bundle/config" do
      apply_silently
      settings = YAML.load(jar.files['WEB-INF/.bundle/config'].string)
      expect(settings['BUNDLE_FROZEN']).to eq 'true'
      # no longer exported via init.rb - the packed .bundle/config is authoritative
      contents = jar.contents('META-INF/init.rb')
      expect(contents.split("\n").grep(/BUNDLE_FROZEN/)).to be_empty
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
        apply_silently
      end

      after do
        rm_rf "Rakefile"
        rm_rf "foo.war"
      end

      it "adds WarMain and JarMain to file" do
        expect(file_list(%r{^warbler/WarMain\.class$})).to_not be_empty
        expect(file_list(%r{^warbler/JarMain\.class$})).to_not be_empty
      end

      it "can run commands in the generated warfile" do
        jar.create('foo.war')
        _, stdout, stderr, wait_thr = Open3.popen3(
          'java ' \
          '--enable-native-access=ALL-UNNAMED --sun-misc-unsafe-memory-access=allow -XX:+IgnoreUnrecognizedVMOptions ' \
          '-jar foo.war -S rake test_task'
        )
        expect(stderr.readlines.join).to eq("")
        expect(wait_thr.value.success?).to be(true)
        expect(stdout.readlines.join).to eq("success\n")
      end
    end
  end

  context "when deployment" do
    run_in_directory "spec/sample_bundler"

    before do
      bundle 'config', 'set', 'deployment', 'true'
    end

    it "does not vendor the (default gem) bundler - the packed JRuby provides it" do
      bundle_install
      apply_silently
      expect(file_list(%r{gems/rake-13.4.2/lib})).to_not be_empty
      expect(file_list(%r{gems/bundler-})).to be_empty
    end

    after do
      bundle 'config', 'set', 'deployment', 'false'
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

describe Warbler::Traits::Bundler, "#warn_on_bundler_version_mismatch" do
  require 'tmpdir'

  let(:trait) { Warbler::Traits::Bundler.allocate }

  def lockfile_with_bundled_with(version)
    dir = Dir.mktmpdir 'bundled-with'
    path = File.join(dir, 'Gemfile.lock')
    File.write path, <<-LOCKFILE.gsub(/^ {6}/, '')
      GEM
        specs:

      PLATFORMS
        ruby

      DEPENDENCIES

      BUNDLED WITH
         #{version}
    LOCKFILE
    Pathname.new(path)
  end

  it "warns when the lockfile BUNDLED WITH differs from the running bundler" do
    allow(::Bundler).to receive(:default_lockfile).and_return lockfile_with_bundled_with('9.9.9')
    expect(trait).to receive(:warn).with(/BUNDLED WITH \(9\.9\.9\) does not match the bundler running warbler \(#{Regexp.escape ::Bundler::VERSION}\)/)
    trait.send :warn_on_bundler_version_mismatch
  end

  it "does not warn when the lockfile BUNDLED WITH matches the running bundler" do
    allow(::Bundler).to receive(:default_lockfile).and_return lockfile_with_bundled_with(::Bundler::VERSION)
    expect(trait).to_not receive(:warn)
    trait.send :warn_on_bundler_version_mismatch
  end

  it "does not warn without a lockfile" do
    allow(::Bundler).to receive(:default_lockfile).and_return Pathname.new('/no/such/Gemfile.lock')
    expect(trait).to_not receive(:warn)
    trait.send :warn_on_bundler_version_mismatch
  end
end
