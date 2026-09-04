require 'zip'

# rubyzip >= 3.6 enables zip64 by default, adding zip64 extra fields that the `java -jar` launcher rejects
Zip.write_zip64_support = false

module Warbler
  class ZipSupport
    def self.create(filename, &blk)
      ::Zip::File.open(filename, create: true, &blk)
    end

    def self.open(filename, &blk)
      Zip::File.open(filename, &blk)
    end
  end
end
