#-*- mode: ruby -*-

# tell the gem setup for maven where the java sources are
# and how to name the jar file (default path for the jar: ./lib )
gemspec( :jar => 'warbler_jar.jar',
         :source => 'ext' )

# just dump the POM as pom.xml as read-only file
properties( 'tesla.dump.pom' => 'pom.xml',
            'tesla.dump.readOnly' => true )

# dependencies needed for compilation
scope :provided do
  jar 'org.jruby:jruby', '1.7.8'
  jar 'org.eclipse.jetty:jetty-webapp', '8.1.9.v20130131'
end

plugin :compiler, '3.1', :source => '1.5', :target => '1.5'

plugin :invoker, '1.8' do
  execute_goals( :install, :run,
                 :id => 'integration-test',
                 :projectsDirectory => 'integration',
                 :streamLogs => true )
end
