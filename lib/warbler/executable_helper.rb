#--
# Copyright (c) 2013 Michal Papis.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

module Warbler
  module ExecutableHelper
    def update_archive_add_executable(jar)
      case executable
      when Array
        gem_name, executable_path = executable
        gem_with_version = config.gems.full_name_for(gem_name, config.gem_dependencies)
        bin_path = apply_pathmaps(config, File.join(gem_with_version, executable_path), :gems)
      else
        bin_path = apply_pathmaps(config, executable, :application)
      end
      add_main_rb(jar, bin_path, config.executable_params)
    end

    def executable
      config.executable ||= default_executable
    end
  end
end
