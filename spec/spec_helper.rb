# frozen_string_literal: true

require 'simplecov'

SimpleCov.start do
  add_filter 'spec'
  add_filter 'config'
end

ENV['ROBOT_ENVIRONMENT'] = 'test'
require File.expand_path("#{__dir__}/../config/boot")

require 'webmock/rspec'
require 'simplecov'
require 'byebug'
include LyberCore::Rspec # rubocop:disable Style/MixinUsage

Retries.sleep_enabled = false # skip delays during testing
