# Make sure specs run with the definitions from test.rb
ENV['ROBOT_ENVIRONMENT'] = 'test'

require 'simplecov'
require 'coveralls'
Coveralls.wear!

SimpleCov.formatter = Coveralls::SimpleCov::Formatter
SimpleCov.start do
  add_filter 'spec'
  add_filter 'config'
end

bootfile = File.join(File.dirname(__FILE__), '..', 'config/boot')
require bootfile

require 'moab'
require 'moab/stanford'
