#!/usr/bin/env ruby

require 'rubygems'
require 'rubygems/dependency_installer'

installer = Gem::DependencyInstaller.new(:force => true)

installer.install( 'bouncy-castle-java', '1.5.0147' )
installer.install( 'rake', '10.1.0' )
installer.install( 'diff-lcs', '1.2.4' )
