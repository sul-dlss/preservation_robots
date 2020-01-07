source 'https://rubygems.org'

gem 'config'
gem 'rake'
gem 'pry' # useful for production environment

# Stanford DLSS gems
gem 'moab-versioning', '>= 4.2.0' # work with Moab Objects; 4.2.0 has DepositBagValidator
gem 'lyber-core', '~> 5.1' # robot code
gem 'dor-services', '~> 7.0'
gem 'honeybadger' # for error reporting / tracking / notifications
gem 'text-table' # to generate tables for StatsReporter
gem 'preservation-client', '~> 2.1'
gem 'whenever' # manage cron for robots and monitoring
gem 'retries'
gem 'resque'
gem 'resque-pool'
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
