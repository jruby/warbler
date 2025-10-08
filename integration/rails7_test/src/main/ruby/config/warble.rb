Warbler::Config.new do |config|
  config.autodeploy_dir = "../../../target"
  config.jar_name = "rails7_test-1.0"

  config.webxml.rails.env = 'development'
end
