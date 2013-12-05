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
require 'maven/tools/jarfile'
require 'jbundler/classpath_file'
require 'jbundler/gemfile_lock'
require 'jbundler/aether'

config = JBundler::Config.new

jarfile = Maven::Tools::Jarfile.new(config.jarfile)
if config.skip
  warn "skip jbundler setup"
else
  classpath_file = JBundler::ClasspathFile.new(config.classpath_file)
  gemfile_lock = JBundler::GemfileLock.new(jarfile, config.gemfile_lock)

  if classpath_file.needs_update?(jarfile, gemfile_lock)
    aether = JBundler::AetherRuby.new(config)

    jarfile.populate_unlocked(aether)
    gemfile_lock.populate_dependencies(aether)
    jarfile.populate_locked(aether)

    aether.resolve

    classpath_file.generate(aether.classpath_array)
    jarfile.generate_lockfile(aether.resolved_coordinates)
  end

  if classpath_file.exists? && jarfile.exists_lock?
    require 'java'
    classpath_file.require_classpath
    if config.verbose
      warn "jbundler classpath:"
      JBUNDLER_CLASSPATH.each do |path|
        warn "\t#{path}"
      end
    end
  end

end
