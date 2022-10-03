# frozen_string_literal: true

require 'retries'
require 'find'

# Robot package to run under multiplexing infrastructure
module Robots
  # Use DorRepo/SdrRepo to match the workflow repo (and avoid name collision with Dor module)
  module SdrRepo
    # The workflow package name - match the actual workflow name, minus ending WF (using CamelCase)
    module PreservationIngest
      # sends ReST Create or Update Version request to PreservationCatalog, depending on whether this
      # is a new Moab or an update to an existing Moab
      class UpdateCatalog < Base
        ROBOT_NAME = 'update-catalog'

        def initialize
          super(WORKFLOW_NAME, ROBOT_NAME)
        end

        def perform(druid)
          LyberCore::Log.debug("#{ROBOT_NAME} #{druid} starting")
          @druid = druid # for base class attr_accessor
          update_catalog
        end

        private

        def update_catalog
          remove_deposit_bag
          with_retries(max_tries: 3, handler: handler("Updating preservation catalog for #{druid}"), rescue: Preservation::Client::Error) do
            Preservation::Client.update(druid: druid,
                                        version: moab_object.current_version_id,
                                        size: moab_object.size,
                                        storage_location: moab_object.storage_root)
          end
        end

        def remove_deposit_bag
          rm_deposit_bag_safely_for_ceph
        rescue StandardError => e
          errmsg = "Error completing ingest for #{druid}: failed to remove deposit bag (#{deposit_bag_pathname}): " \
                   "#{e.message}\n #{e.backtrace.join('\n')}"
          LyberCore::Log.error(errmsg)
          raise(ItemError, errmsg)
        end

        # we stat all the files in the Moab in hopes of preventing issues when reading metadata about
        # files in the newly created Moab version.  this addresses what we suspect to be interplay between
        # Ceph backed storage and our use of hardlinking (instead of e.g. copying) to get content from the
        # deposit bag to the new Moab version.  see https://github.com/sul-dlss/preservation_catalog/issues/1633
        def rm_deposit_bag_safely_for_ceph
          deposit_bag_pathname.rmtree
          stat_moab_dir_contents
        end

        def stat_moab_dir_contents
          Find.find(moab_object.object_pathname) { |path| File.stat(path) }
        end
      end
    end
  end
end
