require 'zip/zip'

module Warbler
  class ZipSupport
    def self.create(filename, &blk)
      Zip::ZipFile.open(filename, Zip::ZipFile::CREATE, &blk)
    end

    def self.open(filename, &blk)
      Zip::ZipFile.open(filename, &blk)
    end
  end
end
