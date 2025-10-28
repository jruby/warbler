require File.expand_path('../../spec_helper', __FILE__)

class Warbler::WebServer::Artifact
  def self.reset_local_repository
    @@local_repository = nil
  end
end

describe Warbler::WebServer::Artifact do

  before(:all) do
    @_env = ENV.to_h
  end

  before do
    Warbler::WebServer::Artifact.reset_local_repository
  end

  after(:all) do
    Warbler::WebServer::Artifact.reset_local_repository
    ENV.clear
    ENV.update @_env
  end

  let(:sample_artifact) do
    Warbler::WebServer::Artifact.new(
      "http://repo2.maven.org/maven2", "org.eclipse.jetty", "jetty-runner", "9.2.9.v20150224"
    )
  end

  it "uses default (maven) local repository" do
    ENV['HOME'] = '/home/borg'
    ENV.delete('M2_HOME'); ENV.delete('MAVEN_HOME')
    expect(sample_artifact.local_repository).to eq "/home/borg/.m2/repository"
  end

  it "detects a custom maven repository setting" do
    ENV['HOME'] = '/home/borg'
    ENV['M2_HOME'] = File.expand_path('../m2_home', File.dirname(__FILE__))
    expect(sample_artifact.local_repository).to eq '/usr/local/maven/repo'
  end

end


describe Warbler::JettyServer do

  it "creates default configuration for jetty" do
    files = {}
    jar = double('jar file')
    allow(jar).to receive(:files).and_return files

    def server = Warbler::JettyServer.new

    server.add(jar)
    expect(files['WEB-INF/webserver.jar']).to match /org\/eclipse\/jetty\/jetty-runner\/9\.4.*\/jetty-runner-9\.4.*.jar/
    expect(files['WEB-INF/webserver.xml'].string).to include 'org.eclipse.jetty.server.Server'

    props = files['WEB-INF/webserver.properties']
              .string
              .each_line(chomp: true)
              .to_h { |line| line.split(' = ', 2) }

    expect(props.keys.to_set).to eql Set.new(
      ['mainclass', 'args', 'args0', 'args1', 'args2', 'args3', 'args4', 'args5', 'args6', 'props', 'jetty.home',
       'org.eclipse.jetty.util.log.class', 'org.eclipse.jetty.util.log.stderr.ESCAPE']
    )

    expect(props['mainclass']).to eq 'org.eclipse.jetty.runner.Runner'
    expect(props['props']).to eq 'jetty.home,org.eclipse.jetty.util.log.class,org.eclipse.jetty.util.log.stderr.ESCAPE'
    expect(props['org.eclipse.jetty.util.log.class']).to eq 'org.eclipse.jetty.util.log.StdErrLog'
    expect(props['org.eclipse.jetty.util.log.stderr.ESCAPE']).to eq 'false'
  end
end