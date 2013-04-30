module Warbler
  class WebServer
    class Artifact < Struct.new(:repo, :group_id, :artifact_id, :version)
      def path_fragment
        @path_fragment ||= "#{group_id.gsub('.', '/')}/#{artifact_id}/#{version}/#{artifact_id}-#{version}.jar"
      end

      def cached_path
        @cached_path ||= File.expand_path("~/.m2/repository/#{path_fragment}")
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
            open(download_url) do |stream|        #:nocov:
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
    end

    def add(jar)
      jar.files["WEB-INF/webserver.jar"] = @artifact.local_path
    end

    def main_class
      'WarMain.class'
    end
  end

  class WinstoneServer < WebServer
    def initialize
      @artifact = Artifact.new(ENV["MAVEN_REPO"] || "http://repo2.maven.org/maven2",
                               "net.sourceforge.winstone", "winstone-lite",
                               ENV["WEBSERVER_VERSION"] || "0.9.10")
    end

    def add(jar)
      super
      jar.files["WEB-INF/webserver.properties"] = StringIO.new(<<-PROPS)
mainclass = winstone.Launcher
args = args0,args1,args2
args0 = --warfile={{warfile}}
args1 = --webroot={{webroot}}
args2 = --directoryListings=false
PROPS
    end
  end

  class JenkinsWinstoneServer < WinstoneServer
    def initialize
      @artifact = Artifact.new("http://repo.jenkins-ci.org/public",
                               "org.jenkins-ci", "winstone",
                               ENV["WEBSERVER_VERSION"] || "0.9.10-jenkins-43")
    end
  end

  class JettyServer < WebServer
    def initialize
      @artifact = Artifact.new(ENV["MAVEN_REPO"] || "http://repo2.maven.org/maven2",
                               "org.jruby.warbler", "warbler-embedded-jetty",
                               ENV["WEBSERVER_VERSION"] || "1.0.0")
    end

    def add(jar)
      super
      jar.files["WEB-INF/webserver.properties"] = StringIO.new(<<-PROPS)
mainclass = JettyWarMain
args = args0
props = jetty.home
args0 = {{warfile}}
jetty.home = {{webroot}}
PROPS
    end
  end

  WEB_SERVERS = Hash.new {|h,k| h["jenkins-ci.winstone"] }
  WEB_SERVERS.update({ "winstone" => WinstoneServer.new,
                       "jenkins-ci.winstone" => JenkinsWinstoneServer.new,
                       "jetty" => JettyServer.new
                     })
end
