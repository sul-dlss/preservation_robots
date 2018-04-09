source 'https://rubygems.org'

gem 'rake'
gem 'pry' # useful for production environment

# Stanford DLSS gems
# FIXME: do we really need dor-services?   Just for Dor::Config ??
gem 'dor-services', '~> 5.28' # for Dor::Config
gem 'moab-versioning', '>= 4.2.0' # work with Moab Objects; 4.2.0 has DepositBagValidator
gem 'lyber-core' # robot code
gem 'robot-controller' # requires Resque
gem 'honeybadger' # for error reporting / tracking / notifications

group :development, :test do
  gem 'pry-byebug'
  gem 'rubocop', '~> 0.52.1', require: false # avoid code churn due to rubocop changes
  gem 'rubocop-rspec'
end

group :test do
  gem 'rspec'
  gem 'coveralls', require: false
end

group :deployment do
  gem 'capistrano-bundler'
  gem 'dlss-capistrano'
end
