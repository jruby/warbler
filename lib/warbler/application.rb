#--
# Copyright (c) 2010-2012 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'rake'

# Extension of Rake::Application that allows the +warble+ command to
# report its name properly and inject its own tasks without a
# Rakefile.
class Warbler::Application < Rake::Application
  include Warbler::RakeHelper

  def initialize
    super
    Warbler.application = self
    @project_loaded = false
  end

  # Sets the application name and loads Warbler's own tasks
  def load_rakefile
    @name = 'warble'

    # Load the main warbler tasks
    wt = Warbler::Task.new

    task :default => wt.name

    desc "Generate a configuration file to customize your archive"
    task :config => "#{wt.name}:config"

    desc "Install Warbler tasks in your Rails application"
    task :pluginize => "#{wt.name}:pluginize"

    desc "Feature: package gem repository inside a jar"
    task :gemjar => "#{wt.name}:gemjar"

    desc "Feature: make an executable archive (runnable + an embedded web server)"
    task :executable => "#{wt.name}:executable"

    desc "Feature: make a runnable archive (e.g. java -jar rails.war -S rake db:migrate)"
    task :runnable => "#{wt.name}:runnable"
    
    desc "Feature: precompile all Ruby files"
    task :compiled => "#{wt.name}:compiled"

    desc "Display version of Warbler"
    task :version => "#{wt.name}:version"
  end

  # Loads the project Rakefile in a separate application
  def load_project_rakefile
    return if @project_loaded
    # Load any application rakefiles to aid in autodetecting applications
    app = Warbler.project_application = Rake::Application.new
    Rake.application = app
    Rake::Application::DEFAULT_RAKEFILES.each do |rf|
      if File.exist?(rf)
        begin
          load rf
        rescue LoadError => e
          load File.join(Dir.getwd, rf)
        end
        break
      end
    end
    Rake.application = self
    @project_loaded = true
  end

  # Run the application: The equivalent code for the +warble+ command
  # is simply <tt>Warbler::Application.new.run</tt>.
  def run
    Rake.application = self
    super
  end

  # Remap the version option to display Warbler version.
  def standard_rake_options
    super.map do |opt|
      if opt.first == '--version'
        ['--version', '-V', "Display the program version.",
         lambda { |value|
           puts "Warbler version #{Warbler::VERSION}"
           exit
         }
        ]
      else
        opt
      end
    end
  end
end
