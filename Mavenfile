#-*- mode: ruby -*-

gemspec( :jar => 'warbler_jar.jar',
         :source => 'ext' )

properties( 'jruby.version' => '1.7.8',
            'tesla.pom.dump' => 'pom.xml',
            'tesla.pom.readOnly' => true )

scope :provided do
  jar 'org.jruby:jruby', '${jruby.version}'
  jar 'org.eclipse.jetty:jetty-webapp', '8.1.9.v20130131'
end

plugin :compiler, :source => '1.5', :target => '1.5'

plugin :invoker do
  execute_goals( :install, :run,
                 :id => 'integration-test',
                 :projectsDirectory => 'integration' )
end
