#
# Copyright (C) 2013 Christian Meier
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
# TODO make nice require after ruby-maven uses the same ruby files
require File.join(File.dirname(File.dirname(__FILE__)), 'model', 'model.rb')
require File.join(File.dirname(__FILE__), 'jarfile.rb')

module Maven
  module Tools

    class ArtifactPassthrough

      def initialize(&block)
        @block = block
      end

      def add_artifact(a)
        @block.call(a)
      end

      def add_repository(name, url)
      end
    end

    class MavenProject < Maven::Model::Project
      tags :dummy

      def load_mavenfile(file)
        file = file.path if file.is_a?(File)
        if File.exists? file
          @current_file = file
          content = File.read(file)
          eval content
        else
          self
        end
      end

      def load_jarfile(file)
        jars = Jarfile.new(file)
        if jars.exists?
          container = ArtifactPassthrough.new do |a|
            artifactId, groupId, extension, version = a.split(/:/)
            send(extension.to_sym, "#{artifactId}:#{groupId}", version)
          end
          if !jars.exists_lock? || jars.mtime > jars.mtime_lock
            jars.populate_unlocked container
          end
          jars.populate_locked container
        end
      end
    end
  end
end
