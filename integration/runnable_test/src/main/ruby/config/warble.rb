Warbler::Config.new do |config|
  config.features = %w(executable)
  config.autodeploy_dir = "../../../target"
  config.jar_name = "test"

  config.includes = FileList["Rakefile"]

  config.gems << "rake"
end
