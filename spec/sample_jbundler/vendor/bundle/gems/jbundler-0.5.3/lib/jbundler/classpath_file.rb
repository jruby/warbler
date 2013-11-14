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
module JBundler

  class ClasspathFile

    def initialize(classpathfile = '.jbundler/classpath.rb')
      @classpathfile = classpathfile
    end

    def require_classpath
      load File.expand_path @classpathfile
    end

    def mtime
      File.mtime(@classpathfile)
    end

    def exists?
      File.exists?(@classpathfile)
    end

    def needs_update?(jarfile, gemfile_lock)
      (jarfile.exists? || gemfile_lock.exists? || jarfile.exists_lock?) && (!exists? || !jarfile.exists_lock? || (jarfile.exists? && (jarfile.mtime > mtime)) || (jarfile.exists_lock? && (jarfile.mtime_lock > mtime)) || (gemfile_lock.exists? && (gemfile_lock.mtime > mtime)))
    end

    def generate(classpath_array)
      FileUtils.mkdir_p(File.dirname(@classpathfile))
      File.open(@classpathfile, 'w') do |f|
        f.puts "JBUNDLER_CLASSPATH = []"
        classpath_array.each do |path|
          f.puts "JBUNDLER_CLASSPATH << '#{path}'" unless path =~ /pom$/
        end
        f.puts "JBUNDLER_CLASSPATH.freeze"
        f.puts "JBUNDLER_CLASSPATH.each { |c| require c }"
        f.close
      end
    end
    
  end
end
