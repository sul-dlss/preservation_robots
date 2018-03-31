# Ensure subsequent requires search the correct local paths
$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), '..', 'robots'))

require 'logger'
# Load the environment file based on Environment.  Default to development
environment = ENV['ROBOT_ENVIRONMENT'] ||= 'development'
ROBOT_ROOT = File.expand_path(File.dirname(__FILE__) + '/..')
ROBOT_LOG = Logger.new(File.join(ROBOT_ROOT, "log/#{environment}.log"))
ROBOT_LOG.level = Logger::SEV_LABEL.index(ENV['ROBOT_LOG_LEVEL']) || Logger::INFO

require 'lyber_core'
LyberCore::Log.set_level(ROBOT_LOG.level)

require 'config'
Config.setup do |config|
  config.use_env = true
  config.env_prefix = 'SETTINGS'
  config.env_separator = '__'
end
Config.load_and_set_settings(Config.setting_files(File.dirname(__FILE__), environment))

require 'dor-workflow-service'
Dor::WorkflowService.configure(
  Settings.workflow.url,
  logger: LyberCore::Log.class_variable_get(:@@log), # reuse a logger
  timeout: Settings.workflow.timeout || 0,
  dor_services_url: Settings.dor_services.url
)

require 'robots'
require 'resque'
Resque.redis = Settings.redis.url || "localhost:6379/resque:#{ENV['ROBOT_ENVIRONMENT']}"
require 'robot-controller'
# require 'moab-versioning'
