# frozen_string_literal: true

source 'https://rubygems.org'

gem 'config'
gem 'rake'
gem 'pry' # useful for production environment

# Stanford DLSS gems
gem 'moab-versioning', '~> 5.1' # work with Moab Objects
gem 'dor-workflow-client', '~> 4.0'
gem 'honeybadger' # for error reporting / tracking / notifications
gem 'lyber-core', '~> 6.1' # robot code
gem 'preservation-client', '~> 4.0'
gem 'resque'
gem 'resque-pool'
gem 'retries'
gem 'slop'
gem 'text-table' # to generate tables for StatsReporter
gem 'whenever' # manage cron for robots and monitoring
gem 'zeitwerk', '~> 2.1'

group :development, :test do
  gem 'pry-byebug'
  gem 'rubocop'
  gem 'rubocop-rspec'
  gem 'simplecov', require: 'false'
  gem 'rspec_junit_formatter' # For circleCI
end

group :test do
  gem 'rspec'
  gem 'webmock'
end

group :deployment do
  gem 'capistrano-bundler'
  gem 'dlss-capistrano', require: false
  gem 'capistrano-rvm'
end
