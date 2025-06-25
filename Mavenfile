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

properties( 'jruby.plugins.version' => '3.0.6-SNAPSHOT',
            'jruby.version' => '9.4.13.0',
            'jetty.version' => '9.4.31.v20200723' )

# dependencies needed for compilation
scope :provided do
  jar 'org.jruby:jruby', '${jruby.version}'
  jar 'org.eclipse.jetty:jetty-webapp', '${jetty.version}'
end

plugin :compiler, '3.1', :source => '8', :target => '8'

plugin :invoker, '1.8' do
  execute_goals( :install, :run,
                 :id => 'integration-test',
                 :properties => { 'warbler.version' => '${project.version}',
                                  'jruby.version' => '${jruby.version}',
                                  'jetty.version' => '${jetty.version}',
                                  'bundler.version' => '2.6.3',
                                  'jruby.plugins.version' => '${jruby.plugins.version}' },

                 :goals => ['verify'],
                 :projectsDirectory => 'integration',
                 :streamLogs => true )
end
