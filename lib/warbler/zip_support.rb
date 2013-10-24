module Warbler
  class ZipSupportRubyZip0_9
    def self.create(filename, &blk)
      Zip::ZipFile.open(filename, Zip::ZipFile::CREATE, &blk)
    end

    def self.open(filename, &blk)
      Zip::ZipFile.open(filename, &blk)
    end
  end

  class ZipSupportRubyZip1_0
    def self.create(filename, &blk)
      Zip::File.open(filename, Zip::File::CREATE, &blk)
    end

    def self.open(filename, &blk)
      Zip::File.open(filename, &blk)
    end
  end
end

begin
  require 'zip/zip'
  Warbler::ZipSupport = Warbler::ZipSupportRubyZip0_9
rescue LoadError => e
  raise e unless e.message =~ /zip/

  require 'zip'
  Warbler::ZipSupport = Warbler::ZipSupportRubyZip1_0
end
