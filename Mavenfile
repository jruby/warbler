#-*- mode: ruby -*-
warn "ruby-maven is running fixed JRuby version #{JRUBY_VERSION}"

require File.expand_path('lib/warbler/version', File.dirname(__FILE__))

id "org.jruby.warbler:warbler-jar:#{Warbler::VERSION}"
packaging 'jar'

properties(
  'project.build.sourceEncoding' => 'UTF-8',
  'maven.compiler.release' => '8',
  'jruby.plugins.version' => '3.0.6',
  'jruby-rack.version' => '1.2',
)

# dependencies needed for compilation
scope :provided do
  jar 'org.jruby:jruby', '${jruby.version}'
end

build do
  source_directory 'ext'
  final_name 'warbler_jar'
end

plugin :clean, '3.5.0', :filesets => [ { :directory => 'lib', :includes => [ 'warbler_jar.jar' ] } ]
plugin :compiler, '3.15.0'
plugin :resources, '3.5.0'
plugin :jar, '3.5.0', :outputDirectory => 'lib' do
  # build the jar before the (rake-driven) gem packaging rather than at package
  execute_goals :jar, :id => 'default-jar', :phase => 'prepare-package'
end
plugin :install, '3.1.4'

plugin :invoker, '3.10.1' do
  execute_goals( :run,
                 :id => 'integration-test',
                 :properties => {
                   'maven.compiler.release' => '${maven.compiler.release}',
                   'jruby.plugins.version' => '${jruby.plugins.version}',
                   'warbler.version' => Warbler::VERSION,
                   'jruby.version' => '${jruby.version}',
                   'jruby-rack.version' => '${jruby-rack.version}',
                   'style.color' => 'always',
                 },
                 :goals => ['verify'],
                 :projectsDirectory => 'integration',
                 :pomIncludes => [ '*/pom.xml' ],
                 :pomExcludes => [],
                 :streamLogs => true )
end
