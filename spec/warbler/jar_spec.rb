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
    cleanup_temp_files include: '*.java'

    it "detects a Jar trait" do
      expect(config.traits).to include(Warbler::Traits::Jar)
    end

    it "collects java libraries" do
      jar.apply(config)
      expect(file_list(%r{^META-INF/lib/jruby-.*\.jar$})).to_not be_empty
    end

    it "adds a JarMain class" do
      jar.apply(config)
      expect(file_list(%r{^JarMain\.class$})).to_not be_empty
    end

    it "adds an init.rb" do
      jar.apply(config)
      expect(file_list(%r{^META-INF/init.rb$})).to_not be_empty
    end

    it "requires 'rubygems' in init.rb" do
      jar.add_init_file(config)
      contents = jar.contents('META-INF/init.rb')
      expect(contents).to match /require 'rubygems'/
    end

    it "does not override ENV['GEM_HOME'] by default" do
      jar.add_init_file(config)
      contents = jar.contents('META-INF/init.rb')
      expect(contents).to include("ENV['GEM_HOME'] =")
    end

    it "overrides ENV['GEM_HOME'] when override_gem_home is set" do
      config.override_gem_home = false
      jar.add_init_file(config)
      contents = jar.contents('META-INF/init.rb')
      expect(contents).to include("ENV['GEM_HOME'] ||=")
    end

    it "adds a main.rb" do
      jar.apply(config)
      expect(file_list(%r{^META-INF/main.rb$})).to_not be_empty
    end

    it "adds script_files" do
      config.script_files << __FILE__
      jar.apply(config)
      expect(file_list(%r{^META-INF/#{File.basename(__FILE__)}$})).to_not be_empty
    end

    it "accepts a custom manifest file" do
      touch 'manifest'
      use_config do |config|
        config.manifest_file = 'manifest'
      end
      jar.apply(config)
      expect(jar.files['META-INF/MANIFEST.MF']).to eq "manifest"
    end

    it "accepts a MANIFEST.MF file if it exists in the project root" do
      touch 'MANIFEST.MF'
      jar.apply(config)
      expect(jar.files['META-INF/MANIFEST.MF']).to eq "MANIFEST.MF"
    end

    it "does not add a manifest if one already exists" do
      jar.files['META-INF/MANIFEST.MF'] = 'manifest'
      jar.add_manifest(config)
      expect(jar.files['META-INF/MANIFEST.MF']).to eq "manifest"
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
        expect(File.exist?("sample.jar")).to eq true
      ensure
        rm_f ['foo.txt', 'bar/bar.txt', 'sample.jar']
        rmdir 'bar'
      end
    end

    context "with a .gemspec" do
      it "detects a Gemspec trait" do
        expect(config.traits).to include(Warbler::Traits::Gemspec)
      end

      it "detects gem dependencies" do
        jar.apply(config)
        expect(file_list(%r{^gems/rubyzip.*/lib/(zip/)?zip.rb})).to_not be_empty
        expect(file_list(%r{^specifications/rubyzip.*\.gemspec})).to_not be_empty
      end

      it "sets load paths in init.rb" do
        jar.add_init_file(config)
        contents = jar.contents('META-INF/init.rb')
        expect(contents).to match /LOAD_PATH\.unshift.*sample_jar\/lib/
      end

      it "loads the default executable in main.rb" do
        jar.apply(config)
        contents = jar.contents('META-INF/main.rb')
        expect(contents).to eq "load 'sample_jar/sbin/sample_jar'"
      end

      it "includes compiled .rb and .class files" do
        config.compiled_ruby_files = %w(lib/sample_jar.rb)
        jar.compile(config)
        jar.apply(config)
        expect(file_list(%r{^sample_jar/lib/sample_jar\.class$})).to_not be_empty
        expect(jar.contents('sample_jar/lib/sample_jar.rb')).to match /load __FILE__\.sub/
      end

      it "includes only specified dirs" do
        config.dirs = %w(bin)
        jar.compile(config)
        jar.apply(config)
        expect(file_list(%r{^sample_jar/lib$})).to be_empty
        expect(file_list(%r{^sample_jar/bin$})).to_not be_empty
      end

      it "excludes .rb and .class files from compile" do
        config.compiled_ruby_files = %w(lib/sample_jar.rb)
        config.excludes += FileList["lib/sample_jar.*"]
        jar.compile(config)
        jar.apply(config)
        expect(file_list(%r{^sample_jar/lib/sample_jar\.class$})).to be_empty
        expect(jar.contents('sample_jar/lib/sample_jar.rb')).to_not match /load __FILE__\.sub/
      end

      it "compiles included gems when compile_gems is true" do
        config.compile_gems = true
        config.compiled_ruby_files = %w(lib/sample_jar.rb)
        jar.compile(config)
        jar.apply(config)
        expect(file_list(%r{sample_jar.*\.rb$}).size).to eq 2
        expect(file_list(%r{gems.*\.class$}).size).to be >= 45 # depending on RubyZip version
      end

      it "does not compile included gems by default" do
        config.compiled_ruby_files = %w(lib/sample_jar.rb)
        jar.compile(config)
        jar.apply(config)
        expect(file_list(%r{sample_jar.*\.rb$}).size).to eq 2
        expect(file_list(%r{gems.*\.class$}).size).to eq 0
      end

      it "compiles with jrubyc options when specified" do
        config.jrubyc_options = [ '--java' ]
        config.compiled_ruby_files = %w(lib/sample_jar.rb)
        jar.compile(config)
        jar.apply(config)
        expect( FileList['*'] ).to include 'SampleJar.java'
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
        expect(contents).to match /load.*sample_jar\/bin\/another_jar/
      end

      it "loads the specified bin/executable in main.rb" do
        use_config do |config|
          config.executable = 'bin/sample_jar'
        end
        silence { jar.apply(config) }
        contents = jar.contents('META-INF/main.rb')
        expect(contents).to match /load.*sample_jar\/bin\/sample_jar/
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
        expect(config.traits).to include(Warbler::Traits::NoGemspec)
      end

      it "collects gem files from configuration" do
        use_config do |config|
          config.gems << "rake"
        end
        jar.apply(config)
        expect(file_list(%r{^gems/rake.*/lib/rake.rb})).to_not be_empty
        expect(file_list(%r{^specifications/rake.*\.gemspec})).to_not be_empty
      end

      it "collects all project files in the directory" do
        touch "extra.foobar"
        jar.apply(config)
        expect(file_list(%r{^sample_jar/bin$})).to_not be_empty
        expect(file_list(%r{^sample_jar/test$})).to_not be_empty
        expect(file_list(%r{^sample_jar/lib/sample_jar.rb$})).to_not be_empty
        expect(file_list(%r{^sample_jar/extra\.foobar$})).to_not be_empty
      end

      it "sets load paths in init.rb" do
        jar.add_init_file(config)
        contents = jar.contents('META-INF/init.rb')
        expect(contents).to match /LOAD_PATH\.unshift.*sample_jar\/lib/
      end

      it "loads the first bin/executable in main.rb" do
        jar.apply(config)
        contents = jar.contents('META-INF/main.rb')
        expect(contents).to match /load.*sample_jar\/bin\/sample_jar/
      end

      it "loads the specified bin/executable in main.rb" do
        use_config do |config|
          config.executable = 'bin/sample_jar_extra'
        end
        jar.apply(config)
        contents = jar.contents('META-INF/main.rb')
        expect(contents).to match /load.*sample_jar\/bin\/sample_jar_extra/
      end

      it "loads the bin/executable from other gem in main.rb" do
        use_config do |config|
          config.gems = [ "rake" ]
          config.executable = ['rake', 'bin/rake']
        end
        jar.apply(config)
        contents = jar.contents('META-INF/main.rb')
        expect(contents).to match /load.*gems\/rake.*\/bin\/rake/
      end

      it "does not set parameters in main.rb" do
        jar.apply(config)
        contents = jar.contents('META-INF/main.rb')
        expect(contents).to_not match /ARGV.*/m
      end

      it "does set parameters in main.rb" do
        use_config do |config|
          config.executable_params = 'do_something'
        end
        jar.apply(config)
        contents = jar.contents('META-INF/main.rb')
        expect(contents).to match /ARGV\.unshift.*do_something/m
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
      expect(config.traits).to include(Warbler::Traits::War)
    end

    it "collects files in public" do
      jar.apply(config)
      expect(file_list(%r{^index\.html})).to_not be_empty
    end

    it "collects gem files" do
      use_config do |config|
        config.gems << 'rake'
      end
      jar.apply(config)
      expect(file_list(%r{WEB-INF/gems/gems/rake.*/lib/rake.rb})).to_not be_empty
      expect(file_list(%r{WEB-INF/gems/specifications/rake.*\.gemspec})).to_not be_empty
    end

    it "collects gem files with dependencies" do
      use_config do |config|
        config.gems << 'virtus'
        config.gem_dependencies = true
      end
      jar.apply(config)
      expect(file_list(%r{WEB-INF/gems/gems/axiom-types.*/lib})).to_not be_empty
      expect(file_list(%r{WEB-INF/gems/specifications/axiom-types.*\.gemspec})).to_not be_empty
      expect(file_list(%r{WEB-INF/gems/gems/equalizer.*/lib/equalizer/version.rb$})).to_not be_empty
      # NOTE: rdoc is tricky as its dependency json is a default gem
      #use_config do |config|
      #  config.gems << "rdoc"
      #  config.gem_dependencies = true
      #end
      #jar.apply(config)
      #expect(file_list(%r{WEB-INF/gems/gems/json.*/lib/json.rb})).to_not be_empty
      #expect(file_list(%r{WEB-INF/gems/specifications/json.*\.gemspec})).to_not be_empty
    end

    it "collects gem files without dependencies" do
      use_config do |config|
        config.gems << 'virtus'
        config.gem_dependencies = false
      end
      jar.apply(config)
      expect(file_list(%r{WEB-INF/gems/gems/axiom-types.*/lib})).to be_empty
      expect(file_list(%r{WEB-INF/gems/specifications/axiom-types.*\.gemspec})).to be_empty
      expect(file_list(%r{WEB-INF/gems/gems/equalizer.*/lib/equalizer/version.rb$})).to be_empty
      #use_config do |config|
      #  config.gems << "rdoc"
      #  config.gem_dependencies = false
      #end
      #jar.apply(config)
      #expect(file_list(%r{WEB-INF/gems/gems/json.*/lib/json.rb})).to be_empty
      #expect(file_list(%r{WEB-INF/gems/specifications/json.*\.gemspec})).to be_empty
    end

    it "adds ENV['GEM_HOME'] to init.rb" do
      jar.add_init_file(config)
      contents = jar.contents('META-INF/init.rb')
      expect(contents).to include("ENV['GEM_HOME'] =")
      expect(contents).to match /WEB-INF\/gems/
    end

    it "overrides ENV['GEM_HOME'] when override_gem_home is set" do
      config.override_gem_home = true
      jar.add_init_file(config)
      contents = jar.contents('META-INF/init.rb')
      expect(contents).to include("ENV['GEM_HOME'] =")
    end

    it "does not include log files by default" do
      jar.apply(config)
      expect(file_list(%r{WEB-INF/log})).to_not be_empty
      expect(file_list(%r{WEB-INF/log/.*\.log})).to be_empty
    end

    def expand_webxml
      jar.apply(config)
      expect(jar.files).to include("WEB-INF/web.xml")
      require 'rexml/document'
      REXML::Document.new(jar.files["WEB-INF/web.xml"]).root.elements
    end

    it "creates a web.xml file" do
      use_config do |config|
        config.webxml.booter = :rack
        config.webxml.jruby.max.runtimes = 5
      end
      elements = expand_webxml
      expect(elements.to_a("context-param/param-name[text()='jruby.max.runtimes']")).to_not be_empty
      expect(elements.to_a("context-param/param-name[text()='jruby.max.runtimes']/../param-value").first.text).to eq "5"

      filters = elements.to_a("filter/filter-class")
      expect( filters.size ).to eql 1
      expect( filters.first.text ).to eql 'org.jruby.rack.RackFilter'
      filters = elements.to_a("filter/filter-name")
      expect( filters.size ).to eql 1
      expect( filters.first.text ).to eql 'RackFilter'
      filters = elements.to_a("filter/async-supported")
      expect( filters.size ).to eql 1
      expect( filters.first.text ).to eql 'false'
      filters = elements.to_a("filter-mapping/filter-name")
      expect( filters.size ).to eql 1
      expect( filters.first.text ).to eql 'RackFilter'
      filters = elements.to_a("filter-mapping/url-pattern")
      expect( filters.size ).to eql 1
      expect( filters.first.text ).to eql '/*'

      listeners = elements.to_a("listener/listener-class")
      expect( listeners.size ).to eql 1
      expect( listeners.first.text ).to eql 'org.jruby.rack.RackServletContextListener'
    end

    it "includes custom context parameters in web.xml" do
      use_config do |config|
        config.webxml.some.custom.config = "myconfig"
      end
      elements = expand_webxml
      expect(elements.to_a("context-param/param-name[text()='some.custom.config']")).to_not be_empty
      expect(elements.to_a("context-param/param-name[text()='some.custom.config']/../param-value").first.text).to eq "myconfig"
    end

    it "allows one jndi resource to be included" do
      use_config do |config|
        config.webxml.jndi = 'jndi/rails'
      end
      elements = expand_webxml
      expect(elements.to_a("resource-ref/res-ref-name[text()='jndi/rails']")).to_not be_empty
    end

    it "allows multiple jndi resources to be included" do
      use_config do |config|
        config.webxml.jndi = ['jndi/rails1', 'jndi/rails2']
      end
      elements = expand_webxml
      expect(elements.to_a("resource-ref/res-ref-name[text()='jndi/rails1']")).to_not be_empty
      expect(elements.to_a("resource-ref/res-ref-name[text()='jndi/rails2']")).to_not be_empty
    end

    it "does not include any ignored context parameters" do
      use_config do |config|
        config.webxml.foo = "bar"
        config.webxml.ignored << "foo"
      end
      elements = expand_webxml
      expect(elements.to_a("context-param/param-name[text()='foo']")).to be_empty
      expect(elements.to_a("context-param/param-name[text()='ignored']")).to be_empty
      expect(elements.to_a("context-param/param-name[text()='jndi']")).to be_empty
    end

    it "uses a config/web.xml if it exists" do
      mkdir_p "config"
      touch "config/web.xml"
      jar.apply(config)
      expect(jar.files["WEB-INF/web.xml"]).to eq "config/web.xml"
    end

    it "uses a config/web.xml.erb if it exists" do
      mkdir_p "config"
      File.open("config/web.xml.erb", "w") {|f| f << "Hi <%= webxml.public.root %>" }
      jar.apply(config)
      expect(jar.files["WEB-INF/web.xml"]).to_not be nil
      expect(jar.files["WEB-INF/web.xml"].read).to eq "Hi /"
    end

    it "collects java libraries" do
      jar.apply(config)
      expect(file_list(%r{WEB-INF/lib/jruby-.*\.jar$})).to_not be_empty
    end

    it "collects application files" do
      jar.apply(config)
      expect(file_list(%r{WEB-INF/app$})).to_not be_empty
      expect(file_list(%r{WEB-INF/config$})).to_not be_empty
      expect(file_list(%r{WEB-INF/lib$})).to_not be_empty
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
      expect(File.exist?(File.join("#{Dir::tmpdir}","warbler.war"))).to eq true
    end

    it "allows the jar extension to be customized" do
      use_config do |config|
        config.jar_name = 'warbler'
        config.jar_extension = 'foobar'
      end
      touch "file.txt"
      jar.files["file.txt"] = "file.txt"
      silence { jar.create(config) }
      expect(File.exist?("warbler.foobar")).to eq true
    end

    it "can exclude files from the .war" do
      use_config do |config|
        config.excludes += FileList['lib/tasks/utils.rake']
      end
      jar.apply(config)
      expect(file_list(%r{lib/tasks/utils.rake})).to be_empty
    end

    it "can exclude public files from the .war" do
      use_config do |config|
        config.excludes += FileList['public/robots.txt']
      end
      jar.apply(config)
      expect(file_list(%r{robots.txt})).to be_empty
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
      expect(t.config.jar_name).to eq "mywar"
    end

    it "fails if a gem is requested that is not installed" do
      use_config do |config|
        config.gems = ["nonexistent-gem"]
      end
      expect(lambda {
        Warbler::Task.new "warble", config
        jar.apply(config)
      }).to raise_error(Gem::MissingSpecError)
    end

    it "allows specification of dependency by Gem::Dependency" do
      spec = double "gem spec"
      allow(spec).to receive(:name).and_return "hpricot"
      allow(spec).to receive(:full_name).and_return "hpricot-0.6.157"
      allow(spec).to receive(:full_gem_path).and_return "hpricot-0.6.157"
      allow(spec).to receive(:loaded_from).and_return "hpricot.gemspec"
      allow(spec).to receive(:files).and_return ["Rakefile"]
      allow(spec).to receive(:dependencies).and_return []
      dep = Gem::Dependency.new("hpricot", "> 0.6")
      expect(dep).to receive(:to_spec).and_return spec
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
      expect(file_list(%r{WEB-INF/classes/Rakefile$})).to_not be_empty
    end

    it "does not try to autodetect frameworks when Warbler.framework_detection is false" do
      begin
        Warbler.framework_detection = false
        task :environment
        expect(config.webxml.booter).to_not eq :rails
        t = Rake::Task['environment']
        class << t; public :instance_variable_get; end
        expect(t.instance_variable_get("@already_invoked")).to eq false
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
          expect(file_list(%r{WEB-INF/lib/app-sample.jar})).to_not be_empty
          expect(file_list(%r{WEB-INF/app/sample.jar})).to_not be_empty
        end

        it "leaves jar files alone that are already in WEB-INF/lib" do
          jar.apply(config)
          expect(file_list(%r{WEB-INF/lib/lib-existing.jar})).to be_empty
          expect(file_list(%r{WEB-INF/lib/existing.jar})).to_not be_empty
        end
      end

      context "with move_jars_to_webinf_lib not set" do
        it "moves jar files to WEB-INF/lib" do
          jar.apply(config)
          expect(file_list(%r{WEB-INF/lib/app-sample.jar})).to be_empty
          expect(file_list(%r{WEB-INF/app/sample.jar})).to_not be_empty
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
          expect(file_list(%r{WEB-INF/lib/app-sample.jar})).to_not be_empty
          expect(file_list(%r{WEB-INF/lib/app-sample2.jar})).to_not be_empty
          expect(file_list(%r{WEB-INF/lib/.*?another.jar})).to be_empty
        end

        it "removes default jars not matched by filter from WEB-INF/lib" do
          jar.apply(config)
          expect(file_list(%r{WEB-INF/lib/jruby-rack.*\.jar})).to be_empty
          expect(file_list(%r{WEB-INF/lib/jruby-core.*\.jar})).to be_empty
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
        expect(file_list(%r{^WarMain\.class$})).to_not be_empty
        expect(file_list(%r{^JarMain\.class$})).to_not be_empty
      end
    end

    context "with the runnable feature" do

      it "adds WarMain (and JarMain) class" do
        use_config do |config|
          config.features << "runnable"
        end
        jar.apply(config)
        expect(file_list(%r{^WarMain\.class$})).to_not be_empty
        expect(file_list(%r{^JarMain\.class$})).to_not be_empty
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
        expect(config.traits).to include(Warbler::Traits::Rails)
      end

      it "auto-detects a Rails application" do
        expect(config.webxml.booter).to eq :rails
        expect(config.gems["rails"]).to eq "2.1.0"
      end

      it "adds the rails.rb to the script files" do
        expect(config.script_files.first).to match %r{lib/warbler/scripts/rails.rb$}
      end

      it "provides Rails gems by default, unless vendor/rails is present" do
        expect(config.gems).to have_key("rails")

        mkdir_p "vendor/rails"
        config = Warbler::Config.new
        expect(config.gems).to be_empty

        rm_rf "vendor/rails"
        allow(@rails).to receive(:vendor_rails?).and_return true
        config = Warbler::Config.new
        expect(config.gems).to be_empty
      end

      it "automatically adds Rails.configuration.gems to the list of gems" do
        task :environment do
          config = double "config"
          allow(@rails).to receive(:configuration).and_return(config)
          gem = double "gem"
          allow(gem).to receive(:name).and_return "hpricot"
          allow(gem).to receive(:requirement).and_return Gem::Requirement.new("=0.6")
          allow(config).to receive(:gems).and_return [gem]
        end

        expect(config.webxml.booter).to eq :rails
        expect(config.gems.keys).to include(Gem::Dependency.new("hpricot", Gem::Requirement.new("=0.6")))
      end

      shared_examples_for "threaded environment" do
        it "sets the jruby min and max runtimes to 1" do
          ENV["RAILS_ENV"] = nil
          expect(config.webxml.booter).to eq :rails
          expect(config.webxml.jruby.min.runtimes).to eq 1
          expect(config.webxml.jruby.max.runtimes).to eq 1
        end

        it "doesn't override already configured runtime numbers" do
          use_config do |config|
            config.webxml.jruby.min.runtimes = 2
            config.webxml.jruby.max.runtimes = 2
          end
          expect(config.webxml.jruby.min.runtimes).to eq 2
          expect(config.webxml.jruby.max.runtimes).to eq 2
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
          expect(config.includes).to include("public/assets/manifest.yml")
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
            expect(config.includes).to include(manifest_file)
          end
        end

        before do
          mkdir File.dirname(manifest_file)
          File.open(manifest_file, "w")
        end

        after do
          rm_rf File.dirname(manifest_file)
        end

        context "when rails version is found in Gemfile.lock" do
          before :each do
            ENV['BUNDLE_GEMFILE'] = File.expand_path('../rails4_stub/Gemfile', File.dirname(__FILE__))
          end

          it_should_behave_like "threaded environment"
          it_should_behave_like "asset pipeline"
        end

        context "when rails version is not found in Gemfile.lock" do
          before :each do
            File.open("Gemfile", 'w') { |f| f.puts "gem 'rails-name'\n\n" }
            File.open("Gemfile.lock", 'w') do |f|
              f.puts " rails-name (4.0.0)"
              f.puts " apry-rails (4.2.0)"
              f.puts ""
            end
          end

          after :each do
            rm "Gemfile"
            rm "Gemfile.lock"
          end

          it "doesn't set runtime numbers to 1" do
            expect(config.webxml.jruby.min.runtimes).to_not eq 1
            expect(config.webxml.jruby.max.runtimes).to_not eq 1
          end

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
        expect(contents).to match /ENV\['RAILS_ENV'\]/
        expect(contents).to match /'production'/
      end
    end

    context 'in Rails app with webpacker' do
      let(:manifest_files) { %w(public/packs/manifest.json public/packs/manifest.json.gz) }

      before do
        allow(Warbler::Traits::Rails).to receive(:detect?).and_return(true)
        mkdir_p File.dirname(manifest_files.first)
        manifest_files.each { |f| touch f }
      end

      after do
        rm_rf File.dirname(manifest_files.first)
      end

      it 'automatically adds webpack manifest files into WEB-INF/public/packs' do
        jar.apply(config)
        expect(file_list(%r{^WEB-INF/public/packs/manifest\.json})).to_not be_empty
        expect(file_list(%r{^WEB-INF/public/packs/manifest\.json.gz})).to_not be_empty
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
        expect(config.traits).to include(Warbler::Traits::Rack)
      end

      it "auto-detects a Rack application with a config.ru file" do
        jar.apply(config)
        expect(jar.files['WEB-INF/config.ru']).to eq 'config.ru'
      end

      it "adds RACK_ENV to init.rb" do
        ENV["RACK_ENV"] = nil
        jar.add_init_file(config)
        contents = jar.contents('META-INF/init.rb')
        expect(contents).to match /ENV\['RACK_ENV'\]/
        expect(contents).to match /'production'/
      end
    end

    it "skips directories that don't exist in config.dirs and print a warning" do
      use_config do |config|
        config.dirs = %w(lib notexist)
      end
      silence { jar.apply(config) }
      expect(file_list(%r{WEB-INF/lib})).to_not be_empty
      expect(file_list(%r{WEB-INF/notexist})).to be_empty
    end

    it "excludes Warbler's old tmp/war directory by default" do
      mkdir_p "tmp/war"
      touch "tmp/war/index.html"
      use_config do |config|
        config.dirs += ["tmp"]
      end
      jar.apply(config)
      expect(file_list(%r{WEB-INF/tmp/war})).to be_empty
      expect(file_list(%r{WEB-INF/tmp/war/index\.html})).to be_empty
    end

    it "writes gems to location specified by gem_path" do
      use_config do |config|
        config.gem_path = "/WEB-INF/jewels"
        config.gems << 'rake'
      end
      elements = expand_webxml
      expect(file_list(%r{WEB-INF/jewels})).to_not be_empty
      expect(elements.to_a("context-param/param-name[text()='gem.path']")).to_not be_empty
      expect(elements.to_a("context-param/param-name[text()='gem.path']/../param-value").first.text).to eq "/WEB-INF/jewels"
    end

    it "allows adding additional WEB-INF files via config.webinf_files" do
      File.open("myserver-web.xml", "w") do |f|
        f << "<web-app></web-app>"
      end
      use_config do |config|
        config.webinf_files = FileList['myserver-web.xml']
      end
      jar.apply(config)
      expect(file_list(%r{WEB-INF/myserver-web.xml})).to_not be_empty
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
      expect(file_list(%r{WEB-INF/myserver-web.xml})).to_not be_empty
      expect(jar.contents('WEB-INF/myserver-web.xml')).to match /web-app.*production/
    end

    it "does not overwrite user-specified webserver.properties file" do
      File.open("webserver.properties", "w") do |f|
        f << "foo"
      end
      use_config do |config|
        config.webinf_files = FileList['webserver.properties']
      end
      jar.apply(config)
      expect(file_list(%r{WEB-INF/webserver\.properties})).to_not be_empty
      expect(jar.contents('WEB-INF/webserver.properties')).to eq 'foo'
    end

    it "excludes test files in gems according to config.gem_excludes" do
      use_config do |config|
        config.gem_excludes += [/^(test|spec)\//]
      end
      jar.apply(config)
      expect(file_list(%r{WEB-INF/gems/gems/rake([^/]+)/test/test_rake.rb})).to be_empty
    end

    it "creates a META-INF/init.rb file with startup config" do
      jar.apply(config)
      expect(file_list(%r{META-INF/init.rb})).to_not be_empty
    end

    it "allows adjusting the init file location in the war" do
      use_config do |config|
        config.init_filename = 'WEB-INF/init.rb'
      end
      jar.add_init_file(config)
      expect(file_list(%r{WEB-INF/init.rb})).to_not be_empty
    end

    it "allows adding custom files' contents to init.rb" do
      use_config do |config|
        config.init_contents << "Rakefile"
      end
      jar.add_init_file(config)
      contents = jar.contents('META-INF/init.rb')
      expect(contents).to match /require 'rake'/
    end

    it "does not have escaped HTML in WARBLER_CONFIG" do
      use_config do |config|
        config.webxml.dummy = '<dummy/>'
      end
      jar.apply(config)
      expect(jar.contents('META-INF/init.rb')).to match /<dummy\/>/
    end
  end
end
