# frozen_string_literal: true

require 'rubygems'
require 'bundler/setup'
Bundler.require(:default)

loader = Zeitwerk::Loader.new
loader.push_dir(File.absolute_path("#{__FILE__}/../../lib"))
loader.setup

LyberCore::Boot.up(__dir__)

Preservation::Client.configure(url: Settings.preservation_catalog.url, token: Settings.preservation_catalog.token)

require 'moab'
require 'moab/stanford'
Moab::Config.configure do
  storage_roots Settings.moab.storage_roots
  storage_trunk Settings.moab.storage_trunk
  deposit_trunk Settings.moab.deposit_trunk
  path_method Settings.moab.path_method
end
