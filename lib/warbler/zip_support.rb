require 'zip'

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
