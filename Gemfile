source 'https://rubygems.org'

# gem 'faraday' # HTTP requests to other ReST services
# gem 'nokogiri' # xml parsing
gem 'rake'
# gem 'retries' # robust handling of network glitches

# Stanford DLSS gems
# gem 'druid-tools' # druid validation and druid-tree parsing
# FIXME: do we really need dor-services?   Just for Dor::Config ??
gem 'dor-services', '~> 5.28' # for Dor::Config
gem 'moab-versioning' # work with Moab Objects
gem 'lyber-core' # robot code
gem 'robot-controller' # requires Resque

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
