#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'ostruct'

module Warbler
  module Traits
    # The War trait sets up the layout and generates web.xml for the war project.
    class War
      include Trait
      include RakeHelper
      include PathmapHelper

      DEFAULT_GEM_PATH = '/WEB-INF/gems'

      def self.detect?
        Traits::Rails.detect? || Traits::Merb.detect? || Traits::Rack.detect?
      end

      def before_configure
        config.gem_path      = DEFAULT_GEM_PATH
        config.pathmaps      = default_pathmaps
        config.webxml        = default_webxml_config
        config.webinf_files  = default_webinf_files
        config.java_libs     = default_jar_files
        config.public_html   = FileList["public/**/{.[!.],.??*,*}"] # include dotfiles
        config.jar_extension = 'war'
        config.init_contents << "#{config.warbler_templates}/war.erb"
      end

      def after_configure
        update_gem_path(DEFAULT_GEM_PATH)
      end

      def default_pathmaps
        p = OpenStruct.new
        p.public_html  = ["%{public/,}p"]
        p.java_libs    = ["WEB-INF/lib/%f"]
        p.java_classes = ["WEB-INF/classes/%p"]
        p.application  = ["WEB-INF/%p"]
        p.webinf       = ["WEB-INF/%{.erb$,}f"]
        p.gemspecs     = ["#{config.relative_gem_path}/specifications/%f"]
        p.gems         = ["#{config.relative_gem_path}/gems/%p"]
        p
      end

      def default_webxml_config
        c = WebxmlOpenStruct.new
        c.public.root = '/'
        c.jndi = nil
        c.ignored = %w(jndi booter)
        c
      end

      def default_webinf_files
        webxml = if File.exist?("config/web.xml")
          "config/web.xml"
        elsif File.exist?("config/web.xml.erb")
          "config/web.xml.erb"
        else
          "#{WARBLER_HOME}/web.xml.erb"
        end
        FileList[webxml]
      end

      def default_jar_files
        require 'jruby-jars'
        require 'jruby-rack'
        FileList[JRubyJars.core_jar_path, JRubyJars.stdlib_jar_path, JRubyJars.jruby_rack_jar_path]
      end

      def update_archive(jar)
        add_public_files(jar)
        add_webxml(jar)
        move_jars_to_webinf_lib(jar, config.move_jars_to_webinf_lib)
        add_runnables(jar) if config.features.include?("runnable")
        add_executables(jar) if config.features.include?("executable")
        add_gemjar(jar) if config.features.include?("gemjar")
      end

      # Add public/static assets to the root of the war file.
      def add_public_files(jar)
        config.public_html.exclude *(config.excludes.to_a)
        config.public_html.map {|f| jar.add_with_pathmaps(config, f, :public_html) }
      end

      # Add web.xml and other WEB-INF configuration files from
      # config.webinf_files to the war file.
      def add_webxml(jar)
        config.webinf_files.each do |wf|
          if wf =~ /\.erb$/
            jar.files[apply_pathmaps(config, wf, :webinf)] = jar.expand_erb(wf, config)
          else
            jar.files[apply_pathmaps(config, wf, :webinf)] = wf
          end
        end
      end

      def add_runnables(jar, main_class = 'WarMain')
        main_class = main_class.sub('.class', '') # handles WarMain.class
        unless config.manifest_file
          manifest = Warbler::Jar::DEFAULT_MANIFEST.chomp + "Main-Class: #{main_class}\n"
          jar.files['META-INF/MANIFEST.MF'] = StringIO.new(manifest)
        end
        [ 'JarMain', 'WarMain', main_class ].uniq.each do |klass|
          jar.files["#{klass}.class"] = jar.entry_in_jar(WARBLER_JAR, "#{klass}.class")
        end
      end

      def add_executables(jar)
        webserver = WEB_SERVERS[config.webserver.to_s]
        webserver.add(jar)
        add_runnables jar, webserver.main_class || 'WarMain'
      end

      def add_gemjar(jar)
        gem_jar = Warbler::Jar.new
        gem_path = Regexp::quote(config.relative_gem_path)
        gems = jar.files.select{|k,v| k =~ %r{#{gem_path}/} }
        gems.each do |k,v|
          gem_jar.files[k.sub(%r{#{gem_path}/}, '')] = v
        end
        jar.files["WEB-INF/lib/gems.jar"] = "tmp/gems.jar"
        jar.files.reject!{|k,v| k =~ /#{gem_path}/ || k == "WEB-INF/tmp/gems.jar"}
        mkdir_p "tmp"
        gem_jar.add_manifest
        gem_jar.create("tmp/gems.jar")
      end

      def move_jars_to_webinf_lib(jar, selector = nil)
        return unless selector # default is false
        selector = /.*/ if selector == true # move all if not a RegExp given
        default_jars = default_jar_files.map { |file| File.basename(file) }
        jar.files.keys.select { |k| k =~ /^WEB-INF\/.*\.jar$/ }.each do |k|
          if k.start_with?('WEB-INF/lib/') # .jar already in WEB-INF/lib
            if default_jars.include? k.sub('WEB-INF/lib/', '')
              # exclude default jar (if it's not matched by selector) :
              jar.files.delete(k) unless selector =~ File.basename(k)
            end
            next
          end
          next unless selector =~ File.basename(k)
          name = k.sub('WEB-INF', '')[1..-1].gsub(/[\/\\]/, '-')
          jar.files["WEB-INF/lib/#{name}"] = jar.files[k]
          jar.files[k] = empty_jar
        end
      end

      def empty_jar
        @empty_jar ||= begin
          t = Tempfile.new(["empty", "jar"])
          path = t.path
          t.close!
          ZipSupport.create(path) do |zipfile|
            zipfile.mkdir("META-INF")
            zipfile.get_output_stream("META-INF/MANIFEST.MF") {|f| f << ::Warbler::Jar::DEFAULT_MANIFEST }
          end
          at_exit { File.delete(path) }
          path
        end
      end

      # Helper class for holding arbitrary config.webxml values for injecting into +web.xml+.
      class WebxmlOpenStruct < OpenStruct

        %w(java com org javax gem).each do |name|
          class_eval "def #{name}; method_missing(:#{name}); end"
        end

        def initialize(key = 'webxml')
          @key = key
          @table = Hash.new { |h, k| h[k] = WebxmlOpenStruct.new(k) }
        end

        def servlet_context_listener
          case self.booter
          when :rack
            "org.jruby.rack.RackServletContextListener"
          when :merb
            "org.jruby.rack.merb.MerbServletContextListener"
          else # :rails, default
            "org.jruby.rack.rails.RailsServletContextListener"
          end
        end

        def [](key)
          new_ostruct_member(key)
          send(key)
        end

        def []=(key, value)
          new_ostruct_member(key)
          send("#{key}=", value)
        end

        def context_params(escape = true)
          require 'cgi'
          params = {}
          @table.each do |k,v|
            case v
            when WebxmlOpenStruct
              nested_params = v.context_params
              nested_params.each do |nk,nv|
                params["#{escape ? CGI::escapeHTML(k.to_s) : k.to_s}.#{nk}"] = nv
              end
            else
              params[escape ? CGI::escapeHTML(k.to_s) : k.to_s] = escape ? CGI::escapeHTML(v.to_s) : v.to_s
            end
          end
          extra_ignored = Array === ignored ? ignored : []
          params.delete_if {|k,v| ['ignored', *extra_ignored].include?(k.to_s) }
          params
        end

        def to_s
          "No value for '#@key' found"
        end
      end
    end
  end
end
