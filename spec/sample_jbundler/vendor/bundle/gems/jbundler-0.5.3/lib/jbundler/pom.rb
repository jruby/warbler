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
require 'fileutils'
require 'tempfile'
require 'maven/tools/coordinate'
require 'securerandom'
require 'java'

module JBundler

  class Pom

    include Maven::Tools::Coordinate

    private
    
    def temp_dir
      @temp_dir ||=
        begin
          # on travis the mktmpdir failed
          d = Dir.mktmpdir rescue FileUtils.mkdir( ".tmp" + SecureRandom.hex( 12) ).first
          at_exit { FileUtils.rm_rf(d.dup) }
          # for jruby-1.7.4 1.8 mode add expand_path
          File.expand_path( d )
        end
    end
      
    def writeElement(xmlWriter,element_name, text)
      xmlWriter.writeStartElement(element_name.to_java)
      xmlWriter.writeCharacters(text.to_java)
      xmlWriter.writeEndElement        
    end
    
    def java_imports
      %w(
           javax.xml.stream.XMLStreamWriter
           javax.xml.stream.XMLOutputFactory
           javax.xml.stream.XMLStreamException
          ).each {|i| java_import i }
    end

    GROUP_ID = 'ruby.bundler'
    
    public
    
    def coordinate
      @coord ||= "#{GROUP_ID}:#{@name}:#{@packaging}:#{@version}"
    end
    
    def file
      @file
    end

    def initialize(name, version, deps, packaging = nil)
      unless defined? XMLOutputFactory
        java_imports
      end

      @name = name
      @packaging = packaging || 'jar'
      @version = version

      @file = File.join(temp_dir, 'pom.xml')

      out = java.io.BufferedOutputStream.new(java.io.FileOutputStream.new(@file.to_java))
      outputFactory = XMLOutputFactory.newFactory()
      xmlStreamWriter = outputFactory.createXMLStreamWriter(out)
      xmlStreamWriter.writeStartDocument
      xmlStreamWriter.writeStartElement("project")
      
      writeElement(xmlStreamWriter,"modelVersion","4.0.0")
      writeElement(xmlStreamWriter,"groupId", GROUP_ID)
      writeElement(xmlStreamWriter,"artifactId", name)
      writeElement(xmlStreamWriter,"version", version.to_s.to_java)
      writeElement(xmlStreamWriter,"packaging", packaging) if packaging
      
      xmlStreamWriter.writeStartElement("dependencies".to_java)
      
      deps.each do |line|
        if coord = to_coordinate(line)
          coords = coord.split(/:/)
          group_id = coords[0]
          artifact_id = coords[1]
          extension = coords[2]
          classifier = nil
          if coords.size == 4
            version = coords[3]
          else
            classifier = coords[3]
            version = coords[4]
          end

          xmlStreamWriter.writeStartElement("dependency".to_java)
          writeElement(xmlStreamWriter,"groupId", group_id)
          writeElement(xmlStreamWriter,"artifactId", artifact_id)
          writeElement(xmlStreamWriter,"version", version)
          
          writeElement(xmlStreamWriter,"type", extension) if extension != 'jar'
          writeElement(xmlStreamWriter,"classifier", classifier) if classifier
          xmlStreamWriter.writeEndElement #dependency
        end
      end
      xmlStreamWriter.writeEndElement #dependencies
      
      xmlStreamWriter.writeEndElement #project
      
      xmlStreamWriter.writeEndDocument
      xmlStreamWriter.close
      out.close
    end
    
  end
end
