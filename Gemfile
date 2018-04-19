source 'https://rubygems.org'

gem 'config'
gem 'rake'
gem 'pry' # useful for production environment

# Stanford DLSS gems
gem 'dor-workflow-service', '>= 2.3' # need 2.3 or higher for get_output_for_step calls
gem 'moab-versioning', '>= 4.2.0' # work with Moab Objects; 4.2.0 has DepositBagValidator
gem 'lyber-core' # robot code
gem 'robot-controller' # robot code
gem 'honeybadger' # for error reporting / tracking / notifications
gem 'text-table' # to generate tables for StatsReporter
gem 'whenever' # manage cron for robots and monitoring
gem 'faraday' # for ReST calls to Preservation Catalog
gem 'retries'

group :development, :test do
  gem 'pry-byebug'
  gem 'rubocop', '~> 0.52.1' # avoid code churn due to rubocop changes
  gem 'rubocop-rspec', '~> 1.23.0' # avoid code churn due to rubocop-rspec changes
end

group :test do
  gem 'rspec'
  gem 'coveralls', require: false
  gem 'webmock'
end

group :deployment do
  gem 'capistrano-bundler'
  gem 'dlss-capistrano'
end
