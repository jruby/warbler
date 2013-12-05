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
require 'rubygems'
require 'jbundler/pom'
require 'bundler'

module JBundler

  class GemfileLock

    def initialize(jarfile, lockfile = 'Gemfile.lock')
      @jarfile = jarfile
      @lockfile = lockfile if File.exists?(lockfile)
    end

    def exists?
      !@lockfile.nil?
    end

    def mtime
      File.mtime(@lockfile) if @lockfile
    end

    def populate_dependencies(aether)
      if @lockfile
        # assuming we run in Bundler context here 
        # since we have a Gemfile.lock :)
        Bundler.load.specs.each do |spec|
          jars = []
          spec.requirements.each do |rr|
            rr.split(/\n/).each do |r|
              jars << r if r =~ /^\s*(jar|pom)\s/
            end
          end
          unless jars.empty?
            pom = Pom.new(spec.name, spec.version, jars, "pom")
            aether.install(pom.coordinate, pom.file)
            unless @jarfile.locked?(pom.coordinate)
              aether.add_artifact(pom.coordinate)
            end
          end
        end
      end
    end
  end
  
end
