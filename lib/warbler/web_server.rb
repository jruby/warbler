module Warbler
  class WebServer
    class Artifact < Struct.new(:repo, :group_id, :artifact_id, :version)

      def path_fragment
        @path_fragment ||= "#{group_id.gsub('.', '/')}/#{artifact_id}/#{version}/#{artifact_id}-#{version}.jar"
      end

      def cached_path
        @cached_path ||= File.join(local_repository, path_fragment)
      end

      def download_url
        @download_url ||= "#{repo}/#{path_fragment}" #:nocov:
      end

      def local_path
        unless File.exist?(cached_path)
          puts "Downloading #{artifact_id}-#{version}.jar" #:nocov:
          FileUtils.mkdir_p File.dirname(cached_path) #:nocov:
          require 'open-uri'                    #:nocov:
          begin
            URI.open(download_url) do |stream|        #:nocov:
              File.open(cached_path, "wb") do |f| #:nocov:
                while buf = stream.read(4096) #:nocov:
                  f << buf                    #:nocov:
                end                           #:nocov:
              end                             #:nocov:
            end                               #:nocov:
          rescue => e
            e.message.concat " - #{download_url}"
            raise e
          end
        end
        cached_path
      end

      @@local_repository = nil

      def local_repository
        @@local_repository ||= begin
          m2_home = File.join(user_home, '.m2')
          if File.exist?(settings = File.join(m2_home, 'settings.xml'))
            local_repo = detect_local_repository(settings)
          end
          if local_repo.nil? && mvn_home = ENV['M2_HOME'] || ENV['MAVEN_HOME']
            if File.exist?(settings = File.join(mvn_home, 'conf/settings.xml'))
              local_repo = detect_local_repository(settings)
            end
          end
          local_repo || File.join(m2_home, 'repository')
        end
      end

      private

      def user_home
        ENV[ 'HOME' ] || begin
          user_home = Dir.home if Dir.respond_to?(:home)
          unless user_home
            user_home = ENV_JAVA[ 'user.home' ] if Object.const_defined?(:ENV_JAVA)
          end
          user_home
        end
      end

      def detect_local_repository(settings); require 'rexml/document'
        doc = REXML::Document.new( File.read( settings ) )
        if local_repo = doc.root.elements['localRepository']
          if ( local_repo = local_repo.first )
            local_repo = local_repo.value
            local_repo = nil if local_repo.empty?
          end
        end
        local_repo
      end

    end

    def add(jar)
      jar.files["WEB-INF/webserver.jar"] = @artifact.local_path
    end

    def main_class
      'WarMain.class'
    end
  end

  class JettyServer < WebServer
    def initialize
      @artifact = Artifact.new(ENV["MAVEN_REPO"] || "https://repo1.maven.org/maven2",
                               "org.eclipse.jetty", "jetty-runner",
                               ENV["WEBSERVER_VERSION"] || "9.4.58.v20250814")
    end

    def add(jar)
      super
      jar.files["WEB-INF/webserver.xml"] ||= StringIO.new(<<-CONFIG)
<?xml version="1.0"?>
<!DOCTYPE Configure PUBLIC "-//Jetty//Configure//EN" "http://www.eclipse.org/jetty/configure.dtd">

<Configure id="Server" class="org.eclipse.jetty.server.Server">
</Configure>
CONFIG

      jar.files["WEB-INF/webserver.properties"] ||= StringIO.new(<<-PROPS)
mainclass = org.eclipse.jetty.runner.Runner
args = args0,args1,args2,args3,args4,args5,args6
props = jetty.home
args0 = --host
args1 = {{host}}
args2 = --port
args3 = {{port}}
args4 = --config
args5 = {{config}}
args6 = {{warfile}}
jetty.home = {{webroot}}
PROPS
    end
  end

  WEB_SERVERS = Hash.new { |hash,_| hash['jetty'] }
  WEB_SERVERS['jetty'] = JettyServer.new

end
