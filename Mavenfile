#-*- mode: ruby -*-

# tell the gem setup for maven where the java sources are
# and how to name the jar file (default path for the jar: ./lib )
gemspec( :jar => 'warbler_jar.jar',
         :source => 'ext' )

plugin_repository( :url => 'https://central.sonatype.com/repository/maven-snapshots/',
                   :id => 'central-snapshots' ) do
  releases 'false'
  snapshots 'true'
end
repository( :url => 'https://central.sonatype.com/repository/maven-snapshots/',
            :id => 'central-snapshots' ) do
  releases 'false'
  snapshots 'true'
end

properties(
  'project.build.sourceEncoding' => 'UTF-8',
  'jruby.plugins.version' => '3.0.6',
  'jetty.version' => '9.4.58.v20250814',
  'bundler.version' => '2.6.3',
)

# dependencies needed for compilation
scope :provided do
  jar 'org.jruby:jruby', '${jruby.version}'
  jar 'org.eclipse.jetty:jetty-webapp', '${jetty.version}'
end

plugin :compiler, '3.14.1', :release => '8'
plugin :resources, '3.3.1'
plugin :jar, '2.6'
plugin :install, '3.1.4'

gem 'bundler', '${bundler.version}'
gem 'jruby-jars', '${jruby.version}'

plugin :invoker, '3.9.1' do
  execute_goals( :install, :run,
                 :id => 'integration-test',
                 :properties => { 'warbler.version' => '${project.version}',
                                  'jruby.version' => '${jruby.version}',
                                  'jetty.version' => '${jetty.version}',
                                  'bundler.version' => '${bundler.version}',
                                  'jruby.plugins.version' => '${jruby.plugins.version}' },

                 :goals => ['verify'],
                 :projectsDirectory => 'integration',
                 :streamLogs => true )
end
