#--
# Copyright (c) 2010 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require 'rake'

# Extension of Rake::Application that allows the +warble+ command to
# report its name properly and inject its own tasks without a
# Rakefile.
class Warbler::Application < Rake::Application
  def initialize
    super
    Warbler.application = self
    @project_loaded = false
  end

  # Sets the application name and loads Warbler's own tasks
  def load_rakefile
    @name = 'warble'

    # Load the main warbler tasks
    Warbler::Task.new

    task :default => :war

    desc "Generate a configuration file to customize your war assembly"
    task :config do
      if File.exists?(Warbler::Config::FILE) && ENV["FORCE"].nil?
        puts "There's another bird sitting on my favorite branch"
        puts "(file '#{Warbler::Config::FILE}' already exists. Pass argument FORCE=1 to override)"
      elsif !File.directory?("config")
        puts "I'm confused; my favorite branch is missing"
        puts "(directory 'config' is missing)"
      else
        cp "#{Warbler::WARBLER_HOME}/warble.rb", Warbler::Config::FILE
      end
    end

    desc "Display version of warbler"
    task :version do
      puts "Warbler version #{Warbler::VERSION}"
    end
  end

  # Loads the project Rakefile in a separate application
  def load_project_rakefile
    return if @project_loaded
    # Load any application rakefiles to aid in autodetecting applications
    app = Warbler.project_application = Rake::Application.new
    Rake.application = app
    Rake::Application::DEFAULT_RAKEFILES.each do |rf|
      if File.exist?(rf)
        load rf
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
end
