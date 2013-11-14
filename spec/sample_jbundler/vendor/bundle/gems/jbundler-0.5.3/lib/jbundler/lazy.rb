#
# Copyright (C) 2013 Kristian Meier
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
# the Software, and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
# FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
require 'jbundler/aether'
require 'maven/tools/coordinate'
module JBundler
  module Lazy

    include Maven::Tools::Coordinate

    def self.included(clazz)
      begin
        require 'java'
        warn ''
        warn 'lazy jar loading does NOT garantee the consistency of the classloader.'
        warn 'duplicated jars with different version and other dependency conflicts can easily occur.'
        warn ''
        warn 'add new jars with:'
        warn ''
        warn "\tjar 'org.yaml:snakeyaml'"
        warn "\tjar 'org.slf4j:slf4j-simple', '>1.1'"
        warn ''
        warn 'show loaded jars with:'
        warn "\tjars"
        warn ''
      rescue LoadError
        warn 'no jar support possible without JRuby - just launching an IRB session'
      end
    end

    def jars
      if jb_classpath.empty?
        puts "\tno jars loaded via jbundler"
      else
        jb_classpath.each do |path|
          puts "\t#{path}"
        end
      end
      nil
    end

    def jar(name, *version)
      unless defined? JRUBY_VERSION
        warn 'no jar support possible without JRuby'
        return
      end
      aether.add_artifact("#{name}:#{to_version(*version)}")
      aether.resolve
      result = false
      aether.classpath_array.each do |path|
        if result ||= (require path)
          warn "added #{path} to classloader"
          jb_classpath << path
        else
          warn "already loaded: #{path}"
        end
      end
      result
    end

    private
    
    def jb_classpath
      @jb_cp ||= defined?(JBUNDLER_CLASSPATH) ? JBUNDLER_CLASSPATH.dup : []
    end

    def jb_config
      @_jb_c ||= JBundler::Config.new
    end

    def aether
      @_aether ||= 
        begin
          aether = JBundler::AetherRuby.new(jb_config)
          jarfile = Maven::Tools::Jarfile.new(jb_config.jarfile)
          gemfile_lock = JBundler::GemfileLock.new(jarfile, 
                                                   jb_config.gemfile_lock)
          jarfile.populate_unlocked(aether)
          gemfile_lock.populate_dependencies(aether) if gemfile_lock.exists?
          jarfile.populate_locked(aether)
          aether
        end
    end
  end
end