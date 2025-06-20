#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.expand_path('../../spec_helper', __FILE__)

describe Warbler::Task do
  run_in_directory "spec/sample_war"
  use_fresh_environment
  use_test_webserver

  let :config do
    Warbler::Config.new do |config|
      config.jar_name = "warbler"
      config.gems = ["rake"]
      config.webserver = "test"
      config.webxml.jruby.max.runtimes = 5
    end
  end

  let(:warble_task) { Warbler::Task.new "warble", config }

  def run_task(t)
    warble_task
    Rake::Task[t].invoke
  end

  before :each do
    @rake = Rake::Application.new
    Rake.application = @rake
    verbose(false)
    mkdir_p "log"
    touch "log/test.log"
  end

  after :each do
    run_task "warble:clean"
    rm_rf "log"
    rm_f FileList["config.ru", "*web.xml", "config/web.xml*", "config/warble.rb",
                  "config/special.txt", "config/link.txt", "tmp/gems.jar",
                  "file.txt", 'Gemfile', 'lib/rakelib', '**/*.class']
  end

  it "should define a clean task for removing the war file" do
    war_file = "#{config.jar_name}.war"
    touch war_file

    run_task "warble:clean"
    expect(File.exist?(war_file)).to eq false
  end

  it "should define a make_gemjar task for storing gems in a jar file" do
    silence { run_task "warble:gemjar"; run_task "warble:files" }
    expect(File.exist?("tmp/gems.jar")).to eq true
    expect(warble_task.jar.files.keys).to_not include(%r{WEB-INF\/gems})
    expect(warble_task.jar.files.keys).to include("WEB-INF/lib/gems.jar")
  end

  it "should define a war task for bundling up everything" do
    files_ran = false; task "warble:files" do; files_ran = true; end
    jar_ran = false; task "warble:jar" do; jar_ran = true; end
    silence { run_task "warble" }
    expect(files_ran).to eq true
    expect(jar_ran).to eq true
  end

  it "should define a jar task for creating the .war" do
    touch "file.txt"
    warble_task.jar.files["file.txt"] = "file.txt"
    silence { run_task "warble:jar" }
    expect(File.exist?("#{config.jar_name}.war")).to eq true
  end

  it "should invoke feature tasks configured in config.features" do
    config.features << "gemjar"
    silence { run_task "warble" }
    expect(warble_task.jar.files.keys).to include("WEB-INF/lib/gems.jar")
  end

  it "should warn and skip unknown features configured in config.features" do
    config.features << "bogus"
    expect(capture { run_task "warble" }).to match /unknown feature `bogus'/
  end

  it "should define an executable task for embedding a server in the war file" do
    silence { run_task "warble:executable"; run_task "warble:files" }
    expect(warble_task.jar.files.keys).to include('WEB-INF/webserver.jar')
  end

  it "should be able to define all tasks successfully" do
    Warbler::Task.new "warble", config
  end

  it "should compile any ruby files specified" do
    config.features << "compiled"
    silence { run_task "warble" }

    java_class_magic_number = [0xCA,0xFE,0xBA,0xBE].map { |magic_char| magic_char.chr }.join

    Warbler::ZipSupport.open("#{config.jar_name}.war") do |zf|
      java_class_header     = zf.get_input_stream('WEB-INF/app/helpers/application_helper.class') {|io| io.read }[0..3]
      ruby_class_definition = zf.get_input_stream('WEB-INF/app/helpers/application_helper.rb') {|io| io.read }

      expect(java_class_header).to eq java_class_magic_number
      expect(ruby_class_definition).to eq %{load __FILE__.sub(/.rb$/, '.class')}
    end
  end

  it "should compile ruby 2 mode" do
    config.features << "compiled"
    silence { run_task "warble" }

    java_class_magic_number = [0xCA,0xFE,0xBA,0xBE].map { |magic_char| magic_char.chr }.join

    Warbler::ZipSupport.open("#{config.jar_name}.war") do |zf|
      java_class_header     = zf.get_input_stream('WEB-INF/lib/ruby_one_nine.class') {|io| io.read }[0..3]
      ruby_class_definition = zf.get_input_stream('WEB-INF/lib/ruby_one_nine.rb') {|io| io.read }

      expect(java_class_header).to eq java_class_magic_number
      expect(ruby_class_definition).to eq %{load __FILE__.sub(/.rb$/, '.class')}
    end
  end

  it "should allow bytecode version in config" do
    config.features << "compiled"
    config.bytecode_version = JRUBY_VERSION > "10" ? 21 : 8
    bytecode_version = [0x00, JRUBY_VERSION > "10"  ? 0x41 : 0x34]
    silence { run_task "warble" }

    Warbler::ZipSupport.open("#{config.jar_name}.war") do |zf|
      class_file_bytes = zf.get_input_stream('WEB-INF/lib/ruby_one_nine.class') {|io| io.read }

      expect(class_file_bytes[0..3]).to eq [0xCA,0xFE,0xBA,0xBE].map { |magic_char| magic_char.chr }.join
      expect(class_file_bytes[6..7]).to eq bytecode_version.map { |magic_char| magic_char.chr }.join.force_encoding("ASCII-8BIT")
    end
  end

  it "should delete .class files after finishing the jar" do
    config.features << "compiled"
    silence { run_task "warble" }
    expect(File.exist?('app/helpers/application_helper.class')).to be false
  end

  context "where symlinks are available" do
    begin
      FileUtils.ln_s "README.txt", "r.txt.symlink", :verbose => false

      it "should process symlinks by storing a file in the archive that has the same contents as the source" do
        File.open("config/special.txt", "wb") {|f| f << "special"}
        Dir.chdir("config") { FileUtils.ln_s "special.txt", "link.txt" }
        silence { run_task "warble" }
        Warbler::ZipSupport.open("#{config.jar_name}.war") do |zf|
          special = zf.get_input_stream('WEB-INF/config/special.txt') {|io| io.read }
          link = zf.get_input_stream('WEB-INF/config/link.txt') {|io| io.read }
          expect(link).to eq special
        end
      end

      it "should process directory symlinks by copying the whole subdirectory" do
        Dir.chdir("lib") { FileUtils.ln_s "tasks", "rakelib" }
        silence { run_task "warble" }
        Warbler::ZipSupport.open("#{config.jar_name}.war") do |zf|
          expect(zf.find_entry("WEB-INF/lib/tasks/utils.rake")).to_not be nil
          expect(zf.find_entry("WEB-INF/lib/rakelib/")).to_not be nil
          expect(zf.find_entry("WEB-INF/lib/rakelib/utils.rake")).to_not be nil if defined?(JRUBY_VERSION)
        end
      end

      FileUtils.rm_f "r.txt.symlink", :verbose => false
    rescue NotImplementedError
    end
  end

  context "with a Bundler Gemfile" do

    run_out_of_process_with_drb if DRB = true

    after do
      if DRB
        drbclient.run_task "warble:clean"
      else
        silence { run_task "warble:clean" }
      end
    end

    it "includes gems from the Gemfile" do
      File.open("Gemfile", "w") {|f| f << "gem 'rspec'"}

      if DRB
        drbclient.run_task "warble"
        config = drbclient.config
      else
       silence { run_task "warble" }
      end

      Warbler::ZipSupport.open("#{config.jar_name}.war") do |zf|
        rspec = config.gems.keys.detect { |spec| spec.name == 'rspec' }
        expect(rspec).to_not be(nil), "expected rspec gem among: #{config.gems.keys.join(' ')}"
        expect(zf.find_entry("WEB-INF/gems/specifications/rspec-#{rspec.version}.gemspec")).to_not be nil
      end
    end
  end
end

describe "Debug targets" do
  run_in_directory "spec/sample_war"

  before(:each) do
    @rake = Rake::Application.new
    Rake.application = @rake
    verbose(false)
    silence { Warbler::Task.new :war, Object.new }
  end

  it "should print out lists of files" do
    expect(capture { Rake::Task["war:debug:includes"].invoke }).to match /include/
    expect(capture { Rake::Task["war:debug:excludes"].invoke }).to match /exclude/
    expect(capture { Rake::Task["war:debug"].invoke }).to match /Config/
  end
end
