#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.expand_path('../../spec_helper', __FILE__)

describe Warbler::Jar do
  use_fresh_rake_application
  use_fresh_environment

  def file_list(regex)
    jar.files.keys.select {|f| f =~ regex }
  end

  def use_config(&block)
    @extra_config = block
  end

  def apply_extra_config(config)
    @extra_config.call(config) if @extra_config
  end

  let(:config) { Warbler::Config.new {|c| apply_extra_config(c) } }
  let(:jar) { Warbler::Jar.new }

  before do
    # We repeatedly load the same gemspec, but we modify it between
    # loads. RubyGems treats the filename as the cache key, not taking
    # into account the modification time or contents.
    Gem::Specification.reset
  end

  context "in a jar project" do
    run_in_directory "spec/sample_jar"
    cleanup_temp_files

    it "detects a Jar trait" do
      config.traits.should include(Warbler::Traits::Jar)
    end

    it "collects java libraries" do
      jar.apply(config)
      file_list(%r{^META-INF/lib/jruby-.*\.jar$}).should_not be_empty
    end

    it "adds a JarMain class" do
      jar.apply(config)
      file_list(%r{^JarMain\.class$}).should_not be_empty
    end

    it "adds an init.rb" do
      jar.apply(config)
      file_list(%r{^META-INF/init.rb$}).should_not be_empty
    end

    it "requires 'rubygems' in init.rb" do
      jar.add_init_file(config)
      contents = jar.contents('META-INF/init.rb')
      contents.should =~ /require 'rubygems'/
    end

    it "does not override ENV['GEM_HOME'] by default" do
      jar.add_init_file(config)
      contents = jar.contents('META-INF/init.rb')
      contents.should include("ENV['GEM_HOME'] =")
    end

    it "overrides ENV['GEM_HOME'] when override_gem_home is set" do
      config.override_gem_home = false
      jar.add_init_file(config)
      contents = jar.contents('META-INF/init.rb')
      contents.should include("ENV['GEM_HOME'] ||=")
    end

    it "adds a main.rb" do
      jar.apply(config)
      file_list(%r{^META-INF/main.rb$}).should_not be_empty
    end

    it "adds script_files" do
      config.script_files << __FILE__
      jar.apply(config)
      file_list(%r{^META-INF/#{File.basename(__FILE__)}$}).should_not be_empty
    end

    it "accepts a custom manifest file" do
      touch 'manifest'
      use_config do |config|
        config.manifest_file = 'manifest'
      end
      jar.apply(config)
      jar.files['META-INF/MANIFEST.MF'].should == "manifest"
    end

    it "accepts a MANIFEST.MF file if it exists in the project root" do
      touch 'MANIFEST.MF'
      jar.apply(config)
      jar.files['META-INF/MANIFEST.MF'].should == "MANIFEST.MF"
    end

    it "does not add a manifest if one already exists" do
      jar.files['META-INF/MANIFEST.MF'] = 'manifest'
      jar.add_manifest(config)
      jar.files['META-INF/MANIFEST.MF'].should == "manifest"
    end

    it "creates a jar" do
      begin
        touch "foo.txt"
        mkdir 'bar'
        touch "bar/bar.txt"

        use_config do |config|
          config.jar_name = 'sample'
        end

        jar.files["foo.txt".freeze] = "foo.txt"
        jar.files["bar".freeze] = "bar" # @see #76 on MRI
        jar.files["bar/bar.txt"] = "bar/bar.txt".freeze

        silence { jar.create(config) }
        File.exist?("sample.jar").should == true
      ensure
        rm_f ['foo.txt', 'bar/bar.txt', 'sample.jar']
        rmdir 'bar'
      end
    end

    context "with a .gemspec" do
      it "detects a Gemspec trait" do
        config.traits.should include(Warbler::Traits::Gemspec)
      end

      it "detects gem dependencies" do
        jar.apply(config)
        file_list(%r{^gems/rubyzip.*/lib/(zip/)?zip.rb}).should_not be_empty
        file_list(%r{^specifications/rubyzip.*\.gemspec}).should_not be_empty
      end

      it "sets load paths in init.rb" do
        jar.add_init_file(config)
        contents = jar.contents('META-INF/init.rb')
        contents.should =~ /LOAD_PATH\.unshift.*sample_jar\/lib/
      end

      it "loads the default executable in main.rb" do
        jar.apply(config)
        contents = jar.contents('META-INF/main.rb')
        contents.should =~ /load.*sample_jar\/bin\/sample_jar/
      end

      it "includes compiled .rb and .class files" do
        config.compiled_ruby_files = %w(lib/sample_jar.rb)
        jar.compile(config)
        jar.apply(config)
        file_list(%r{^sample_jar/lib/sample_jar\.class$}).should_not be_empty
        jar.contents('sample_jar/lib/sample_jar.rb').should =~ /load __FILE__\.sub/
      end

      it "includes only specified dirs" do
        config.dirs = %w(bin)
        jar.compile(config)
        jar.apply(config)
        file_list(%r{^sample_jar/lib$}).should be_empty
        file_list(%r{^sample_jar/bin$}).should_not be_empty
      end

      it "excludes .rb and .class files from compile" do
        config.compiled_ruby_files = %w(lib/sample_jar.rb)
        config.excludes += FileList["lib/sample_jar.*"]
        jar.compile(config)
        jar.apply(config)
        file_list(%r{^sample_jar/lib/sample_jar\.class$}).should be_empty
        jar.contents('sample_jar/lib/sample_jar.rb').should_not =~ /load __FILE__\.sub/
      end

      it "compiles included gems when compile_gems is true" do
        config.compile_gems = true
        config.compiled_ruby_files = %w(lib/sample_jar.rb)
        jar.compile(config)
        jar.apply(config)
        file_list(%r{sample_jar.*\.rb$}).size.should == 2
        if RUBY_VERSION >= '1.9'
          file_list(%r{gems.*\.class$}).size.should == 80
        else
          # 1.8.7 uses an older version of rubyzip and so the number of files compiled changes
          file_list(%r{gems.*\.class$}).size.should == 32
        end
      end

      it "does not compile included gems by default" do
        config.compiled_ruby_files = %w(lib/sample_jar.rb)
        jar.compile(config)
        jar.apply(config)
        file_list(%r{sample_jar.*\.rb$}).size.should == 2
        if RUBY_VERSION >= '1.9'
          file_list(%r{gems.*\.class$}).size.should == 0
        else
          # 1.8.7 uses an older version of rubyzip and so the number of files compiled changes
          file_list(%r{gems.*\.class$}).size.should == 0
        end
      end

    end

    context "with a gemspec without a default executable" do
      before :each do
        Dir['*.gemspec'].each do |f|
          cp f, "#{f}.tmp"
          lines = IO.readlines(f)
          File.open(f, 'w') do |io|
            lines.each do |line|
              next if line =~ /executable/
              io << line
            end
          end
        end
      end

      after :each do
        Dir['*.gemspec.tmp'].each {|f| mv f, "#{f.sub /\.tmp$/, ''}"}
      end

      it "loads the first bin/executable in main.rb" do
        silence { jar.apply(config) }
        contents = jar.contents('META-INF/main.rb')
        contents.should =~ /load.*sample_jar\/bin\/another_jar/
      end

      it "loads the specified bin/executable in main.rb" do
        use_config do |config|
          config.executable = 'bin/sample_jar'
        end
        silence { jar.apply(config) }
        contents = jar.contents('META-INF/main.rb')
        contents.should =~ /load.*sample_jar\/bin\/sample_jar/
      end
    end

    context "without a .gemspec" do
      before :each do
        Dir['*.gemspec'].each {|f| mv f, "#{f}.tmp"}
      end

      after :each do
        Dir['*.gemspec.tmp'].each {|f| mv f, "#{f.sub /\.tmp$/, ''}"}
      end

      it "detects a NoGemspec trait" do
        config.traits.should include(Warbler::Traits::NoGemspec)
      end

      it "collects gem files from configuration" do
        use_config do |config|
          config.gems << "rake"
        end
        jar.apply(config)
        file_list(%r{^gems/rake.*/lib/rake.rb}).should_not be_empty
        file_list(%r{^specifications/rake.*\.gemspec}).should_not be_empty
      end

      it "collects all project files in the directory" do
        touch "extra.foobar"
        jar.apply(config)
        file_list(%r{^sample_jar/bin$}).should_not be_empty
        file_list(%r{^sample_jar/test$}).should_not be_empty
        file_list(%r{^sample_jar/lib/sample_jar.rb$}).should_not be_empty
        file_list(%r{^sample_jar/extra\.foobar$}).should_not be_empty
      end

      it "sets load paths in init.rb" do
        jar.add_init_file(config)
        contents = jar.contents('META-INF/init.rb')
        contents.should =~ /LOAD_PATH\.unshift.*sample_jar\/lib/
      end

      it "loads the first bin/executable in main.rb" do
        jar.apply(config)
        contents = jar.contents('META-INF/main.rb')
        contents.should =~ /load.*sample_jar\/bin\/sample_jar/
      end

      it "loads the specified bin/executable in main.rb" do
        use_config do |config|
          config.executable = 'bin/sample_jar_extra'
        end
        jar.apply(config)
        contents = jar.contents('META-INF/main.rb')
        contents.should =~ /load.*sample_jar\/bin\/sample_jar_extra/
      end

      it "loads the bin/executable from other gem in main.rb" do
        use_config do |config|
          config.gems = [ "rake" ]
          config.executable = ['rake', 'bin/rake']
        end
        jar.apply(config)
        contents = jar.contents('META-INF/main.rb')
        contents.should =~ /load.*gems\/rake.*\/bin\/rake/
      end

      it "does not set parameters in main.rb" do
        jar.apply(config)
        contents = jar.contents('META-INF/main.rb')
        contents.should_not =~ /ARGV.*/m
      end

      it "does set parameters in main.rb" do
        use_config do |config|
          config.executable_params = 'do_something'
        end
        jar.apply(config)
        contents = jar.contents('META-INF/main.rb')
        contents.should =~ /ARGV\.unshift.*do_something/m
      end

    end
  end

  context "in a war project" do
    run_in_directory "spec/sample_war"
    cleanup_temp_files

    before(:each) do
      mkdir_p "log"
      touch "log/test.log"
    end

    it "detects a War trait" do
      config.traits.should include(Warbler::Traits::War)
    end

    it "collects files in public" do
      jar.apply(config)
      file_list(%r{^index\.html}).should_not be_empty
    end

    it "collects gem files" do
      use_config do |config|
        config.gems << "rake"
      end
      jar.apply(config)
      file_list(%r{WEB-INF/gems/gems/rake.*/lib/rake.rb}).should_not be_empty
      file_list(%r{WEB-INF/gems/specifications/rake.*\.gemspec}).should_not be_empty
    end

    it "collects gem files with dependencies" do
      use_config do |config|
        config.gems << "rdoc"
        config.gem_dependencies = true
      end
      jar.apply(config)
      file_list(%r{WEB-INF/gems/gems/json.*/lib/json.rb}).should_not be_empty
      file_list(%r{WEB-INF/gems/specifications/json.*\.gemspec}).should_not be_empty
    end

    it "collects gem files without dependencies" do
      use_config do |config|
        config.gems << "rdoc"
        config.gem_dependencies = false
      end
      jar.apply(config)
      file_list(%r{WEB-INF/gems/gems/json.*/lib/json.rb}).should be_empty
      file_list(%r{WEB-INF/gems/specifications/json.*\.gemspec}).should be_empty
    end

    it "adds ENV['GEM_HOME'] to init.rb" do
      jar.add_init_file(config)
      contents = jar.contents('META-INF/init.rb')
      contents.should include("ENV['GEM_HOME'] =")
      contents.should =~ /WEB-INF\/gems/
    end

    it "overrides ENV['GEM_HOME'] when override_gem_home is set" do
      config.override_gem_home = true
      jar.add_init_file(config)
      contents = jar.contents('META-INF/init.rb')
      contents.should include("ENV['GEM_HOME'] =")
    end

    it "does not include log files by default" do
      jar.apply(config)
      file_list(%r{WEB-INF/log}).should_not be_empty
      file_list(%r{WEB-INF/log/.*\.log}).should be_empty
    end

    def expand_webxml
      jar.apply(config)
      jar.files.should include("WEB-INF/web.xml")
      require 'rexml/document'
      REXML::Document.new(jar.files["WEB-INF/web.xml"]).root.elements
    end

    it "creates a web.xml file" do
      use_config do |config|
        config.webxml.jruby.max.runtimes = 5
      end
      elements = expand_webxml
      elements.to_a(
                    "context-param/param-name[text()='jruby.max.runtimes']"
                    ).should_not be_empty
      elements.to_a(
                    "context-param/param-name[text()='jruby.max.runtimes']/../param-value"
                    ).first.text.should == "5"
    end

    it "includes custom context parameters in web.xml" do
      use_config do |config|
        config.webxml.some.custom.config = "myconfig"
      end
      elements = expand_webxml
      elements.to_a(
                    "context-param/param-name[text()='some.custom.config']"
                    ).should_not be_empty
      elements.to_a(
                    "context-param/param-name[text()='some.custom.config']/../param-value"
                    ).first.text.should == "myconfig"
    end

    it "allows one jndi resource to be included" do
      use_config do |config|
        config.webxml.jndi = 'jndi/rails'
      end
      elements = expand_webxml
      elements.to_a(
                    "resource-ref/res-ref-name[text()='jndi/rails']"
                    ).should_not be_empty
    end

    it "allows multiple jndi resources to be included" do
      use_config do |config|
        config.webxml.jndi = ['jndi/rails1', 'jndi/rails2']
      end
      elements = expand_webxml
      elements.to_a(
                    "resource-ref/res-ref-name[text()='jndi/rails1']"
                    ).should_not be_empty
      elements.to_a(
                    "resource-ref/res-ref-name[text()='jndi/rails2']"
                    ).should_not be_empty
    end

    it "does not include any ignored context parameters" do
      use_config do |config|
        config.webxml.foo = "bar"
        config.webxml.ignored << "foo"
      end
      elements = expand_webxml
      elements.to_a(
                    "context-param/param-name[text()='foo']"
                    ).should be_empty
      elements.to_a(
                    "context-param/param-name[text()='ignored']"
                    ).should be_empty
      elements.to_a(
                    "context-param/param-name[text()='jndi']"
                    ).should be_empty
    end

    it "uses a config/web.xml if it exists" do
      mkdir_p "config"
      touch "config/web.xml"
      jar.apply(config)
      jar.files["WEB-INF/web.xml"].should == "config/web.xml"
    end

    it "uses a config/web.xml.erb if it exists" do
      mkdir_p "config"
      File.open("config/web.xml.erb", "w") {|f| f << "Hi <%= webxml.public.root %>" }
      jar.apply(config)
      jar.files["WEB-INF/web.xml"].should_not be nil
      jar.files["WEB-INF/web.xml"].read.should == "Hi /"
    end

    it "collects java libraries" do
      jar.apply(config)
      file_list(%r{WEB-INF/lib/jruby-.*\.jar$}).should_not be_empty
    end

    it "collects application files" do
      jar.apply(config)
      file_list(%r{WEB-INF/app$}).should_not be_empty
      file_list(%r{WEB-INF/config$}).should_not be_empty
      file_list(%r{WEB-INF/lib$}).should_not be_empty
    end

    it "accepts an autodeploy directory where the war should be created" do
      require 'tmpdir'
      use_config do |config|
        config.jar_name = 'warbler'
        config.autodeploy_dir = Dir::tmpdir
      end
      touch "file.txt"
      jar.files["file.txt"] = "file.txt"
      silence { jar.create(config) }
      File.exist?(File.join("#{Dir::tmpdir}","warbler.war")).should == true
    end

    it "allows the jar extension to be customized" do
      use_config do |config|
        config.jar_name = 'warbler'
        config.jar_extension = 'foobar'
      end
      touch "file.txt"
      jar.files["file.txt"] = "file.txt"
      silence { jar.create(config) }
      File.exist?("warbler.foobar").should == true
    end

    it "can exclude files from the .war" do
      use_config do |config|
        config.excludes += FileList['lib/tasks/utils.rake']
      end
      jar.apply(config)
      file_list(%r{lib/tasks/utils.rake}).should be_empty
    end

    it "can exclude public files from the .war" do
      use_config do |config|
        config.excludes += FileList['public/robots.txt']
      end
      jar.apply(config)
      file_list(%r{robots.txt}).should be_empty
    end

    it "reads configuration from #{Warbler::Config::FILE}" do
      mkdir_p "config"
      File.open(Warbler::Config::FILE, "w") do |dest|
        contents =
          File.open("#{Warbler::WARBLER_HOME}/warble.rb") do |src|
          src.read
        end
        dest << contents.sub(/# config\.jar_name/, 'config.jar_name'
                             ).sub(/# config.gems << "tzinfo"/, 'config.gems = []')
      end
      t = Warbler::Task.new "warble"
      t.config.jar_name.should == "mywar"
    end

    it "fails if a gem is requested that is not installed" do
      use_config do |config|
        config.gems = ["nonexistent-gem"]
      end
      lambda {
        Warbler::Task.new "warble", config
        jar.apply(config)
      }.should raise_error
    end

    it "allows specification of dependency by Gem::Dependency" do
      spec = double "gem spec"
      spec.stub(:name).and_return "hpricot"
      spec.stub(:full_name).and_return "hpricot-0.6.157"
      spec.stub(:full_gem_path).and_return "hpricot-0.6.157"
      spec.stub(:loaded_from).and_return "hpricot.gemspec"
      spec.stub(:files).and_return ["Rakefile"]
      spec.stub(:dependencies).and_return []
      dep = Gem::Dependency.new("hpricot", "> 0.6")
      dep.should_receive(:to_spec).and_return spec
      use_config do |config|
        config.gems = [dep]
      end
      silence { jar.apply(config) }
    end

    it "copies loose java classes to WEB-INF/classes" do
      use_config do |config|
        config.java_classes = FileList["Rakefile"]
      end
      jar.apply(config)
      file_list(%r{WEB-INF/classes/Rakefile$}).should_not be_empty
    end

    it "does not try to autodetect frameworks when Warbler.framework_detection is false" do
      begin
        Warbler.framework_detection = false
        task :environment
        config.webxml.booter.should_not == :rails
        t = Rake::Task['environment']
        class << t; public :instance_variable_get; end
        t.instance_variable_get("@already_invoked").should == false
      ensure
        Warbler.framework_detection = true
      end
    end

    context "with embedded jar files" do
      before :each do
        touch FileList["app/sample.jar", "lib/existing.jar"]
      end
      after :each do
        rm_f FileList["app/sample.jar", "lib/existing.jar"]
      end

      context "with move_jars_to_webinf_lib set to true" do
        before :each do
          use_config do |config|
            config.move_jars_to_webinf_lib = true
          end
        end

        it "moves jar files to WEB-INF/lib" do
          jar.apply(config)
          file_list(%r{WEB-INF/lib/app-sample.jar}).should_not be_empty
          file_list(%r{WEB-INF/app/sample.jar}).should_not be_empty
        end

        it "leaves jar files alone that are already in WEB-INF/lib" do
          jar.apply(config)
          file_list(%r{WEB-INF/lib/lib-existing.jar}).should be_empty
          file_list(%r{WEB-INF/lib/existing.jar}).should_not be_empty
        end
      end

      context "with move_jars_to_webinf_lib not set" do
        it "moves jar files to WEB-INF/lib" do
          jar.apply(config)
          file_list(%r{WEB-INF/lib/app-sample.jar}).should be_empty
          file_list(%r{WEB-INF/app/sample.jar}).should_not be_empty
        end
      end

      context "with move_jars_to_webinf_lib set to regexp" do
        before :each do
          use_config do |config|
            config.move_jars_to_webinf_lib = /sample/
          end
        end

        before :each do
          touch FileList["app/another.jar", "app/sample2.jar"]
        end
        after :each do
          rm_f FileList["app/another.jar", "app/sample2.jar"]
        end

        it "moves jar files that match to WEB-INF/lib" do
          jar.apply(config)
          file_list(%r{WEB-INF/lib/app-sample.jar}).should_not be_empty
          file_list(%r{WEB-INF/lib/app-sample2.jar}).should_not be_empty
          file_list(%r{WEB-INF/lib/.*?another.jar}).should be_empty
        end

        it "removes default jars not matched by filter from WEB-INF/lib" do
          jar.apply(config)
          file_list(%r{WEB-INF/lib/jruby-rack.*\.jar}).should be_empty
          file_list(%r{WEB-INF/lib/jruby-core.*\.jar}).should be_empty
        end

      end

    end

    context "with the executable feature" do
      use_test_webserver

      it "adds WarMain (and JarMain) class" do
        use_config do |config|
          config.webserver = "test"
          config.features << "executable"
        end
        jar.apply(config)
        file_list(%r{^WarMain\.class$}).should_not be_empty
        file_list(%r{^JarMain\.class$}).should_not be_empty
      end
    end

    context "with the runnable feature" do

      it "adds WarMain (and JarMain) class" do
        use_config do |config|
          config.features << "runnable"
        end
        jar.apply(config)
        file_list(%r{^WarMain\.class$}).should_not be_empty
        file_list(%r{^JarMain\.class$}).should_not be_empty
      end

    end

    context "in a Rails application" do
      before :each do
        @rails = nil
        task :environment do
          @rails = mock_rails_module
        end
      end

      def mock_rails_module
        rails = Module.new
        Object.const_set("Rails", rails)
        version = Module.new
        rails.const_set("VERSION", version)
        version.const_set("STRING", "2.1.0")
        rails
      end

      it "detects a Rails trait" do
        config.traits.should include(Warbler::Traits::Rails)
      end

      it "auto-detects a Rails application" do
        config.webxml.booter.should == :rails
        config.gems["rails"].should == "2.1.0"
      end

      it "adds the rails.rb to the script files" do
        config.script_files.first.should =~ %r{lib/warbler/scripts/rails.rb$}
      end

      it "provides Rails gems by default, unless vendor/rails is present" do
        config.gems.should have_key("rails")

        mkdir_p "vendor/rails"
        config = Warbler::Config.new
        config.gems.should be_empty

        rm_rf "vendor/rails"
        @rails.stub(:vendor_rails?).and_return true
        config = Warbler::Config.new
        config.gems.should be_empty
      end

      it "automatically adds Rails.configuration.gems to the list of gems" do
        task :environment do
          config = double "config"
          @rails.stub(:configuration).and_return(config)
          gem = double "gem"
          gem.stub(:name).and_return "hpricot"
          gem.stub(:requirement).and_return Gem::Requirement.new("=0.6")
          config.stub(:gems).and_return [gem]
        end

        config.webxml.booter.should == :rails
        config.gems.keys.should include(Gem::Dependency.new("hpricot", Gem::Requirement.new("=0.6")))
      end

      shared_examples_for "threaded environment" do
        it "sets the jruby min and max runtimes to 1" do
          ENV["RAILS_ENV"] = nil
          config.webxml.booter.should == :rails
          config.webxml.jruby.min.runtimes.should == 1
          config.webxml.jruby.max.runtimes.should == 1
        end

        it "doesn't override already configured runtime numbers" do
          use_config do |config|
            config.webxml.jruby.min.runtimes = 2
            config.webxml.jruby.max.runtimes = 2
          end
          config.webxml.jruby.min.runtimes.should == 2
          config.webxml.jruby.max.runtimes.should == 2
        end
      end

      context "with asset_pipeline" do
        let (:manifest_file) { "public/assets/manifest.yml" }

        before do
          mkdir File.dirname(manifest_file)
          File.open(manifest_file, "w")
        end

        after do
          rm_rf File.dirname(manifest_file)
        end

        it "automatically adds asset pipeline manifest file to the included files" do
          config.includes.should include("public/assets/manifest.yml")
        end
      end

      context "with threadsafe! enabled in production.rb" do
        before :each do
          cp "config/environments/production.rb", "config/environments/production.rb.orig"
          File.open("config/environments/production.rb", "a") { |f| f.puts "", "config.threadsafe!" }
        end

        after :each do
          mv "config/environments/production.rb.orig", "config/environments/production.rb"
        end

        it_should_behave_like "threaded environment"
      end

      context "with threadsafe! enabled in environment.rb" do
        before :each do
          cp "config/environment.rb", "config/environment.rb.orig"
          File.open("config/environment.rb", "a") { |f| f.puts "", "config.threadsafe!" }
        end

        after :each do
          mv "config/environment.rb.orig", "config/environment.rb"
        end

        it_should_behave_like "threaded environment"
      end

      context "with rails version 4" do

        let (:manifest_file) { "public/assets/.sprockets-manifest-1234.json" }

        shared_examples_for "asset pipeline" do
          it "automatically adds asset pipeline manifest file to the included files" do
            config.includes.should include(manifest_file)
          end
        end

        before do
          mkdir File.dirname(manifest_file)
          File.open(manifest_file, "w")
        end

        after do
          rm_rf File.dirname(manifest_file)
        end

        context "When rails version is specified in Gemfile" do
          before :each do
            File.open("Gemfile", "a") { |f| f.puts "gem 'rails', '4.0.0'" }
          end

          after :each do
            rm "Gemfile"
          end

          it_should_behave_like "threaded environment"
          it_should_behave_like "asset pipeline"
        end

        context "when rails version is not specified in Gemfile" do
          before :each do
            File.open("Gemfile", "a") { |f| f.puts "gem 'rails'" }
            File.open("Gemfile.lock", "a") { |f| f.puts " rails (4.0.0)" }
          end

          after :each do
            rm "Gemfile"
            rm "Gemfile.lock"
          end

          it_should_behave_like "threaded environment"
          it_should_behave_like "asset pipeline"
        end
      end


      it "adds RAILS_ENV to init.rb" do
        ENV["RAILS_ENV"] = nil
        use_config do |config|
          config.webxml.booter = :rails
        end
        jar.add_init_file(config)
        contents = jar.contents('META-INF/init.rb')
        contents.should =~ /ENV\['RAILS_ENV'\]/
        contents.should =~ /'production'/
      end
    end

    context "in a Merb application" do
      before :each do
        touch "config/init.rb"
        @merb = nil
        task :merb_env do
          @merb = mock_merb_module
        end
      end

      after :each do
        rm_f "config/init.rb"
      end

      def mock_merb_module
        merb = Module.new
        silence { Object.const_set("Merb", merb) }
        boot_loader = Module.new
        merb.const_set("BootLoader", boot_loader)
        merb.const_set("VERSION", "1.0")
        dependencies = Class.new do
          @dependencies = []
          def self.dependencies
            @dependencies
          end
          def self.dependencies=(deps)
            @dependencies = deps
          end
        end
        boot_loader.const_set("Dependencies", dependencies)
        dependencies
      end

      it "detects a Merb trait" do
        config.traits.should include(Warbler::Traits::Merb)
      end

      it "auto-detects a Merb application" do
        config.webxml.booter.should == :merb
        config.gems.keys.should_not include("rails")
      end

      it "automatically adds Merb::BootLoader::Dependencies.dependencies to the list of gems" do
        task :merb_env do
          @merb.dependencies = [Gem::Dependency.new("merb-core", ">= 1.0.6.1")]
        end
        config.gems.keys.should include(Gem::Dependency.new("merb-core", ">= 1.0.6.1"))
      end

      it "skips Merb development dependencies" do
        task :merb_env do
          @merb.dependencies = [Gem::Dependency.new("rake", "= #{RAKEVERSION}", :development)]
        end
        jar.apply(config)
        file_list(/rake-#{RAKEVERSION}/).should be_empty
      end

      it "warns about using Merb < 1.0" do
        task :merb_env do
          silence { Object.const_set("Merb", Module.new) }
        end
        silence { config.webxml.booter.should == :merb }
      end
    end

    context "in a Rack application" do
      before :each do
        mkdir 'tmp' unless File.directory?('tmp')
        Dir.chdir('tmp')
        rackup = "run Proc.new {|env| [200, {}, ['Hello World']]}"
        File.open("config.ru", "w") {|f| f << rackup }
      end

      after :each do
        Dir.chdir('..')
        rm_rf 'tmp'
      end

      it "detects a Rack trait" do
        config.traits.should include(Warbler::Traits::Rack)
      end

      it "auto-detects a Rack application with a config.ru file" do
        jar.apply(config)
        jar.files['WEB-INF/config.ru'].should == 'config.ru'
      end

      it "adds RACK_ENV to init.rb" do
        ENV["RACK_ENV"] = nil
        jar.add_init_file(config)
        contents = jar.contents('META-INF/init.rb')
        contents.should =~ /ENV\['RACK_ENV'\]/
        contents.should =~ /'production'/
      end
    end

    it "skips directories that don't exist in config.dirs and print a warning" do
      use_config do |config|
        config.dirs = %w(lib notexist)
      end
      silence { jar.apply(config) }
      file_list(%r{WEB-INF/lib}).should_not be_empty
      file_list(%r{WEB-INF/notexist}).should be_empty
    end

    it "excludes Warbler's old tmp/war directory by default" do
      mkdir_p "tmp/war"
      touch "tmp/war/index.html"
      use_config do |config|
        config.dirs += ["tmp"]
      end
      jar.apply(config)
      file_list(%r{WEB-INF/tmp/war}).should be_empty
      file_list(%r{WEB-INF/tmp/war/index\.html}).should be_empty
    end

    it "writes gems to location specified by gem_path" do
      use_config do |config|
        config.gem_path = "/WEB-INF/jewels"
        config.gems << 'rake'
      end
      elements = expand_webxml
      file_list(%r{WEB-INF/jewels}).should_not be_empty
      elements.to_a(
                    "context-param/param-name[text()='gem.path']"
                    ).should_not be_empty
      elements.to_a(
                    "context-param/param-name[text()='gem.path']/../param-value"
                    ).first.text.should == "/WEB-INF/jewels"
    end

    it "allows adding additional WEB-INF files via config.webinf_files" do
      File.open("myserver-web.xml", "w") do |f|
        f << "<web-app></web-app>"
      end
      use_config do |config|
        config.webinf_files = FileList['myserver-web.xml']
      end
      jar.apply(config)
      file_list(%r{WEB-INF/myserver-web.xml}).should_not be_empty
    end

    it "allows expanding of additional WEB-INF files via config.webinf_files" do
      ENV["RAILS_ENV"] = nil
      File.open("myserver-web.xml.erb", "w") do |f|
        f << "<web-app><%= webxml.rails.env %></web-app>"
      end
      use_config do |config|
        config.webinf_files = FileList['myserver-web.xml.erb']
      end
      jar.apply(config)
      file_list(%r{WEB-INF/myserver-web.xml}).should_not be_empty
      jar.contents('WEB-INF/myserver-web.xml').should =~ /web-app.*production/
    end

    it "excludes test files in gems according to config.gem_excludes" do
      use_config do |config|
        config.gem_excludes += [/^(test|spec)\//]
      end
      jar.apply(config)
      file_list(%r{WEB-INF/gems/gems/rake([^/]+)/test/test_rake.rb}).should be_empty
    end

    it "creates a META-INF/init.rb file with startup config" do
      jar.apply(config)
      file_list(%r{META-INF/init.rb}).should_not be_empty
    end

    it "allows adjusting the init file location in the war" do
      use_config do |config|
        config.init_filename = 'WEB-INF/init.rb'
      end
      jar.add_init_file(config)
      file_list(%r{WEB-INF/init.rb}).should_not be_empty
    end

    it "allows adding custom files' contents to init.rb" do
      use_config do |config|
        config.init_contents << "Rakefile"
      end
      jar.add_init_file(config)
      contents = jar.contents('META-INF/init.rb')
      contents.should =~ /require 'rake'/
    end

    it "does not have escaped HTML in WARBLER_CONFIG" do
      use_config do |config|
        config.webxml.dummy = '<dummy/>'
      end
      jar.apply(config)
      jar.contents('META-INF/init.rb').should =~ /<dummy\/>/
    end
  end
end
