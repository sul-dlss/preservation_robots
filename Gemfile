source 'https://rubygems.org'

gem 'config'
gem 'rake'
gem 'pry' # useful for production environment

# Stanford DLSS gems
gem 'moab-versioning', '>= 4.2.0' # work with Moab Objects; 4.2.0 has DepositBagValidator
gem 'dor-services', '~> 7.0'
gem 'dor-workflow-client', '~> 3.21'
gem 'honeybadger' # for error reporting / tracking / notifications
gem 'lyber-core', '~> 6.1' # robot code
gem 'preservation-client', '>= 3.1' # 3.x or greater is needed for token auth
gem 'resque'
gem 'resque-pool'
gem 'retries'
gem 'text-table' # to generate tables for StatsReporter
gem 'whenever' # manage cron for robots and monitoring
gem 'zeitwerk', '~> 2.1'

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
  gem 'capistrano-resque-pool'
end
