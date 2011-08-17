module Warbler
  module PathmapHelper
    def apply_pathmaps(config, file, pathmaps)
      file = file.to_s
      file = file[2..-1] if file =~ /^\.\//
      pathmaps = config.pathmaps.send(pathmaps)
      pathmaps.each do |p|
        file = file.pathmap(p)
      end if pathmaps
      file
    end
  end
end
