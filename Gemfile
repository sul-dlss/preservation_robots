source 'https://rubygems.org'

gem 'config'
gem 'rake'
gem 'pry' # useful for production environment

# Stanford DLSS gems
gem 'moab-versioning', '~> 4.2' # work with Moab Objects
gem 'dor-workflow-client', '~> 3.21'
gem 'honeybadger' # for error reporting / tracking / notifications
gem 'lyber-core', '~> 6.1' # robot code
gem 'preservation-client', '~> 3.4' # 3.x or greater is needed for token auth
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
  gem 'rspec_junit_formatter' # For circleCI
end

group :test do
  gem 'rspec'
  gem 'coveralls', require: false
  gem 'webmock'
end

group :deployment do
  gem 'capistrano-bundler'
  gem 'dlss-capistrano', '~> 3.11'
  gem 'capistrano-rvm'
end
