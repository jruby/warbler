#--
# Copyright (c) 2010-2011 Engine Yard, Inc.
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
        config.public_html   = FileList["public/**/*"]
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

      def add_executables(jar)
        winstone_type = ENV["WINSTONE"] || "winstone-lite"
        winstone_version = ENV["WINSTONE_VERSION"] || "0.9.10"
        winstone_path = "net/sourceforge/winstone/#{winstone_type}/#{winstone_version}/#{winstone_type}-#{winstone_version}.jar"
        winstone_jar = File.expand_path("~/.m2/repository/#{winstone_path}")
        unless File.exist?(winstone_jar)
          # Not always covered in tests as these lines may not get
          # executed every time if the jar is cached.
          puts "Downloading #{winstone_type}.jar" #:nocov:
          mkdir_p File.dirname(winstone_jar)      #:nocov:
          require 'open-uri'                      #:nocov:
          maven_repo = ENV["MAVEN_REPO"] || "http://repo2.maven.org/maven2" #:nocov:
          open("#{maven_repo}/#{winstone_path}") do |stream| #:nocov:
            File.open(winstone_jar, "wb") do |f| #:nocov:
              while buf = stream.read(4096) #:nocov:
                f << buf                    #:nocov:
              end                           #:nocov:
            end                             #:nocov:
          end                               #:nocov:
        end

        jar.files['META-INF/MANIFEST.MF'] = StringIO.new(Warbler::Jar::DEFAULT_MANIFEST.chomp + "Main-Class: WarMain\n")
        jar.files['WarMain.class'] = jar.entry_in_jar("#{WARBLER_HOME}/lib/warbler_jar.jar", 'WarMain.class')
        jar.files['WEB-INF/winstone.jar'] = winstone_jar
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

      # Helper class for holding arbitrary config.webxml values for injecting into +web.xml+.
      class WebxmlOpenStruct < OpenStruct
        %w(java com org javax gem).each do |name|
          undef_method name        if Object.methods.include?(name)
          undef_method name.to_sym if Object.methods.include?(name.to_sym)
        end

        def initialize(key = 'webxml')
          @key = key
          @table = Hash.new {|h,k| h[k] = WebxmlOpenStruct.new(k) }
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
