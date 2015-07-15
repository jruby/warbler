require File.expand_path('../../spec_helper', __FILE__)

class Warbler::WebServer::Artifact
  def self.reset_local_repository
    @@local_repository = nil
  end
end

describe Warbler::WebServer::Artifact do

  @@_env = ENV.dup

  after(:all) { ENV.clear; ENV.update @@_env }

  before do
    Warbler::WebServer::Artifact.reset_local_repository
  end

  after(:all) do
    Warbler::WebServer::Artifact.reset_local_repository
  end

  let(:sample_artifact) do
    Warbler::WebServer::Artifact.new("http://repo.jenkins-ci.org/public",
      "org.jenkins-ci", "winstone", "0.9.10-jenkins-43"
    )
  end

  it "uses default (maven) local repository" do
    ENV['HOME'] = '/home/borg'
    ENV.delete('M2_HOME'); ENV.delete('MAVEN_HOME')
    sample_artifact.local_repository.should == "/home/borg/.m2/repository"
  end

  it "detects a custom maven repository setting" do
    ENV['HOME'] = '/home/borg'
    ENV['M2_HOME'] = File.expand_path('../m2_home', File.dirname(__FILE__))
    sample_artifact.local_repository.should == '/usr/local/maven/repo'
  end

end
