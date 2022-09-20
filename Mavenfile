#-*- mode: ruby -*-

# tell the gem setup for maven where the java sources are
# and how to name the jar file (default path for the jar: ./lib )
gemspec( :jar => 'warbler_jar.jar',
         :source => 'ext' )

properties( 'jruby.plugins.version' => '2.0.1',
            'jruby.version' => '9.2.21.0',
            'jetty.version' => '9.4.31.v20200723' )

# dependencies needed for compilation
scope :provided do
  jar 'org.jruby:jruby', '${jruby.version}'
  jar 'org.eclipse.jetty:jetty-webapp', '${jetty.version}'
end

plugin :compiler, '3.1', :source => '1.6', :target => '1.6'

plugin :invoker, '1.8' do
  execute_goals( :install, :run,
                 :id => 'integration-test',
                 :properties => { 'warbler.version' => '${project.version}',
                                  'jruby.version' => '${jruby.version}',
                                  'jetty.version' => '${jetty.version}',
                                  'bundler.version' => '1.12.5',
                                  'jruby.plugins.version' => '${jruby.plugins.version}' },

                 :goals => ['verify'],
                 :projectsDirectory => 'integration',
                 :streamLogs => true )
end
