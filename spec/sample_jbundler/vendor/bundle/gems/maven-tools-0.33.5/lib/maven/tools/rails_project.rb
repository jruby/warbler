#
# Copyright (C) 2013 Christian Meier
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
# the Software, and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
# FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
require File.join(File.dirname(__FILE__), 'gem_project.rb')
module Maven
  module Tools
    class RailsProject < GemProject
      tags :dummy

      def initialize(name = dir_name, &block)
        super(name, &block)
        group_id "rails"
        packaging "war"
      end
      
      def has_gem?(gem)
        assets = profile(:assets)
        self.gem?(gem) || (assets && assets.gem?(gem))
      end

      def add_defaults(args = {})
        self.name = "#{dir_name} - rails application" unless name
        
        # setup bundler plugin
        plugin(:bundler)

        s_args = args.dup
        s_args.delete(:jruby_plugins)
        super(s_args)

        versions = VERSIONS.merge(args)
        
        rails_gem = dependencies.detect { |d| d.type.to_sym == :gem && d.artifact_id.to_s =~ /^rail.*s$/ } # allow rails or railties

        if !jar?("org.jruby:jruby-complete") && !jar?("org.jruby:jruby-core") && versions[:jruby_version]
          minor = versions[:jruby_version].sub(/[0-9]*\./, '').sub(/\..*/, '')

          #TODO once jruby-core pom is working !!!
          if minor.to_i > 55 #TODO fix minor minimum version
            jar("org.jruby:jruby-core", versions[:jruby_version])
            jar("org.jruby:jruby-stdlib", versions[:jruby_version])
            # override deps which works
            jar("jline:jline", '0.9.94') if versions[:jruby_version] =~ /1.6.[1-2]/
            jar("org.jruby.extras:jffi", '1.0.8', 'native') if versions[:jruby_version] =~ /1.6.[0-2]/
            jar("org.jruby.extras:jaffl", '0.5.10') if versions[:jruby_version] =~ /1.6.[0-2]/
          else
            jar("org.jruby:jruby-complete", "${jruby.version}") 
          end
        end

        jar("org.jruby.rack:jruby-rack", versions[:jruby_rack]) unless jar?("org.jruby.rack:jruby-rack")

        self.properties = {
          "jruby.version" => versions[:jruby_version],
          "rails.env" => "development",
          "gem.includeRubygemsInTestResources" => false
        }.merge(self.properties)

        dependencies.find { |d| d.artifact_id == 'bundler' }.scope = nil

        plugin(:rails3) do |rails|
          rails.version = "${jruby.plugins.version}" unless rails.version
          rails.in_phase(:validate).execute_goal(:initialize)
        end

        plugin(:war, versions[:war_plugin]) unless plugin?(:war)
        plugin(:war) do |w|
          options = {
            :webResources => Maven::Model::NamedArray.new(:resource) do |l|
              l << { :directory => "public" }
              l << { 
                :directory => ".",
                :targetPath => "WEB-INF",
                :includes => ['app/**', 'config/**', 'lib/**', 'vendor/**', 'Gemfile']
              }
              l << {
                :directory => '${gem.path}',
                :targetPath => 'WEB-INF/gems',
                :includes => ['gems/**', 'specifications/**']
              }
              if plugin(:bundler).dependencies.detect { |d| d.type.to_sym == :gem }
                l << {
                  :directory => '${gem.path}-bundler-maven-plugin',
                  :targetPath => 'WEB-INF/gems',
                  :includes => ['specifications/**']
                }
              end
            end
          }
          options[:webXml] = 'config/web.xml' if File.exists?('config/web.xml') || !File.exists?('src/main/webapp/WEB-INF/web.xml')
          w.with options
        end

        profile(:assets).activation.by_default if profiles.key?(:assets)
        profile(:development).activation.by_default
        profile(:test).activation.by_default
        profile(:test).activation.property("rails.env", "test")
        profile(:production) do |prod|   
          prod.activation.property("rails.env", "production")
          prod.properties = { 
            "gem.home" => "${project.build.directory}/rubygems-production", 
            "gem.path" => "${project.build.directory}/rubygems-production" 
          }.merge(prod.properties)
        end
      end
    end
  end
end

if $0 == __FILE__
  proj = Maven::Tools::RailsProject.new
  proj.load(ARGV[0] || 'Gemfile')
  proj.load(ARGV[1] || 'Mavenfile')
  proj.add_defaults
  puts proj.to_xml
end