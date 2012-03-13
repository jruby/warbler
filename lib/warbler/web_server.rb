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

    def initialize(artifacts)
      @artifacts = artifacts
    end

    def add(jar)
      artifacts.each do |a|
        jar.files["WEB-INF/#{a.artifact_id}.jar"] = a.local_path
      end
    end

    def main_class
      'WarMain.class'
    end
  end

  class WinstoneServer < WebServer
    def initialize
      super([Artifact.new(ENV["MAVEN_REPO"] || "http://repo2.maven.org/maven2",
                          "net.sourceforge.winstone", "winstone-lite",
                          ENV["WEBSERVER_VERSION"] || "0.9.10")])
    end
  end

  class JenkinsWinstoneServer < WebServer
    def initialize
      super([Artifact.new("http://maven.jenkins-ci.org/content/groups/artifacts",
                          "org.jenkins-ci", "winstone",
                          ENV["WEBSERVER_VERSION"] || "0.9.10-jenkins-35")])
    end
  end

  class JettyServer < WebServer
    def initialize
      super([Artifact.new(ENV["MAVEN_REPO"] || "http://repo2.maven.org/maven2",
                          "org.jruby.warbler", "warbler-embedded-jetty",
                          ENV["WEBSERVER_VERSION"] || "1.0.0")])
    end
  end

  WEB_SERVERS = Hash.new {|h,k| h["jenkins-ci.winstone"] }
  WEB_SERVERS.update({ "winstone" => WinstoneServer.new,
                       "jenkins-ci.winstone" => JenkinsWinstoneServer.new,
                       "jetty" => JettyServer.new
                     })
end
