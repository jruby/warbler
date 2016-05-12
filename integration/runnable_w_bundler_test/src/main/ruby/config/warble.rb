Warbler::Config.new do |config|
  config.features = %w(executable)
  config.autodeploy_dir = "../../../target"
  config.jar_name = "test"

  config.includes = FileList["Gemfile*"] + FileList["bin/*rb"]
end
