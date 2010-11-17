#--
#
# This class proceses paths with the same logic
# as JRuby's org.jruby.util.JavaNameMangler
# because that system is used to transform
# paths and ruby file names into java
# packages and thus we must use the same
# logic when generating require statements
# or specify class files for gemspecs
#
#++

require 'pathname'

module Warbler
  class JavaNameMangler
    #
    # Returns a string representation of a sub(...)
    # statement that transforms a ruby path into the
    # appropriate java path using the name mangling
    # rules including transforming the .rb extension
    #
    def self.subtitution_string(ruby_path)
      escaped_ruby_path = Regexp.escape(ruby_path)
      "sub(%r{#{escaped_ruby_path}$},'#{mangle_path(ruby_path)}')"
    end

    #
    # Mangles a path such as path/to/dir/with/file.rb
    # into path/to/dir/with/file.cass using all the
    # appropriate Java jar name mangling rules
    #
    def self.mangle_path(path_to_file)
      directories, filename = File.split(path_to_file)

      extension = File.extname(filename)
      basename  = File.basename(filename, extension)

      path_elements = []
      Pathname.new(directories).each_filename do |directory_part|
        path_elements << mangle_string_for_clean_java_identifier(directory_part)
      end
      path_elements << "#{mangle_string_for_clean_java_identifier(basename)}.class"

      File.join(path_elements)
    end

    #
    # Using the Java jar name mangling rules, transform
    # a single path component. This is a reimplementation
    # of JRuby's JavaNameMangler#mangleStringForCleanJavaIdentifier
    #
    # NOTE: we are not 100% compatible because we do not
    #       honor Java's Character.isJavaIdentifierStart
    #       logic.
    #
    def self.mangle_string_for_clean_java_identifier(string)
      clean_buffer         = []
      previous_was_replace = false

      string.each_char do |char|
        if char =~ PART_REGEX
          clean_buffer << char
          previous_was_replace = false
        else
          clean_buffer << "_" unless previous_was_replace
          clean_buffer << replace_java_special_char(char)
          clean_buffer << "_"
          previous_was_replace = true
        end
      end

      clean_buffer.join
    end

    #
    # These rules were extracted from JRuby's
    # JavaNameMangler.mangleStringForCleanJavaIdentifier
    #
    def self.replace_java_special_char(char)
      case char
        when '.' then 'dot'
        when '?' then 'p'
        when '!' then 'b'
        when '<' then 'lt'
        when '>' then 'gt'
        when '=' then 'equal'
        when '[' then 'lbracket'
        when ']' then 'rbracket'
        when '+' then 'plus'
        when '-' then 'minus'
        when '*' then 'times'
        when '/' then 'div'
        when '&' then 'and'
        else          char.unpack('H*')[0]
      end
    end

    private

    START_REGEX = /[A-Za-z0-9\$_]/
    PART_REGEX  = /[A-Za-z0-9\$_]/
  end
end
