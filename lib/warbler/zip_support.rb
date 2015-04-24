require 'zip'

module Warbler
  class ZipSupport
    def self.create(filename, &blk)
      Zip::File.open(filename, Zip::File::CREATE, &blk)
    end

    def self.open(filename, &blk)
      Zip::File.open(filename, &blk)
    end
  end
end
