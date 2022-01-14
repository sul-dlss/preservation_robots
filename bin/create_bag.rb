#!/usr/bin/env ruby
# frozen_string_literal: true

# This script can be used to pull objects from preservation, if we need to re-accession it into DOR.
#
# must run this from ~/preservation_robots/current/
# usage is ruby /directory/of/script/create_bag.rb /directory/with/druids/druid-list.txt /some/directory
# where /directory/of/script/createBag.rb is whereever you place this particular script
# and where /directory/with/druids/druid-list.txt is whereever your druid file list is
# NOTE: druids should be each on their own line in the list. Provide either the fully qualified druid (druid:pv564yb1711) or not (pv564yb1711)
# and where /some/directory is wherever you want the bags to land.  i usually place them in the tmp directory.

require 'rubygems'
require 'bundler/setup'
require 'moab/stanford'
require 'yaml'

# rubocop:disable Style/MixinUsage
include Stanford
# rubocop:enable Style/MixinUsage

settings = YAML.load_file('../config/environments/prod.yml')

Moab::Config.configure do
  storage_roots settings['moab']['storage_roots'].sort
  storage_trunk 'sdr2objects'
  deposit_trunk 'deposit'
  path_method 'druid_tree'
end

druids = []
druidlist = File.open(ARGV[0])
druidlist.each_line { |line| druids.push line.chomp }

druids.each do |druid|
  druid = druid.delete_prefix('druid:')
  storage_object = StorageServices.find_storage_object(druid)
  version_id = storage_object.current_version_id
  bag_dir = "#{ARGV[1]}/bags/#{druid}"
  storage_object.reconstruct_version(version_id, bag_dir)
rescue ObjectNotFoundException => e
  puts "#{druid}, #{e}"
end
