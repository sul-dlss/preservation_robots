# frozen_string_literal: true

source 'https://rubygems.org'

gem 'config'
gem 'pry' # useful for production environment
gem 'rake'

# Stanford DLSS gems
gem 'dor-services-client'
gem 'honeybadger' # for error reporting / tracking / notifications
gem 'lyber-core'
gem 'moab-versioning' # work with Moab Objects
gem 'preservation-client'
gem 'retries'
gem 'sidekiq', '~> 8.0'
gem 'slop'
gem 'zeitwerk'

source 'https://gems.contribsys.com/' do
  gem 'sidekiq-pro'
end

group :development, :test do
  gem 'pry-byebug'
  gem 'rspec_junit_formatter' # For circleCI
  gem 'rubocop'
  gem 'rubocop-capybara'
  gem 'rubocop-factory_bot'
  gem 'rubocop-rspec'
  gem 'rubocop-rspec_rails'
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
