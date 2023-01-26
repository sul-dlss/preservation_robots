# frozen_string_literal: true

source 'https://rubygems.org'

gem 'config'
gem 'pry' # useful for production environment
gem 'rake'

# Stanford DLSS gems
gem 'dor-workflow-client', '~> 5.0'
gem 'honeybadger' # for error reporting / tracking / notifications
gem 'lyber-core', '~> 6.1' # robot code
gem 'moab-versioning', '~> 6.0' # work with Moab Objects
gem 'preservation-client', '~> 5.0'
gem 'redis', '~> 4.0' # redis 5.x has breaking changes with resque, see https://github.com/resque/resque/issues/1821
gem 'resque'
gem 'resque-pool'
gem 'retries'
gem 'slop'
gem 'text-table' # to generate tables for StatsReporter
gem 'whenever' # manage cron for robots and monitoring
gem 'zeitwerk', '~> 2.1'

group :development, :test do
  gem 'pry-byebug'
  gem 'rspec_junit_formatter' # For circleCI
  gem 'rubocop'
  gem 'rubocop-rspec'
  gem 'simplecov', require: 'false'
end

group :test do
  gem 'rspec'
  gem 'webmock'
end

group :deployment do
  gem 'capistrano-bundler'
  gem 'dlss-capistrano', require: false
end
