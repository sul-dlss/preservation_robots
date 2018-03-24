source 'https://rubygems.org'

gem 'config'
# gem 'faraday' # HTTP requests to other ReST services
# gem 'nokogiri' # xml parsing
gem 'rake'
# gem 'retries' # robust handling of network glitches

# Stanford DLSS gems
gem 'dor-workflow-service', '~> 2.2'
# gem 'druid-tools' # druid validation and druid-tree parsing
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

# group :deployment do
#   gem 'dlss-capistrano'
# end
