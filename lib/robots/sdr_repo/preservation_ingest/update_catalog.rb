# frozen_string_literal: true

require 'retries'

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
          wait_as_needed # give Ceph MDS some breathing room on the pres cat side, see comment on method
          with_retries(max_tries: 3, handler: handler("Updating preservation catalog for #{druid}"), rescue: Preservation::Client::Error) do
            Preservation::Client.update(druid: druid,
                                        version: moab_object.current_version_id,
                                        size: moab_object.size,
                                        storage_location: moab_object.storage_root)
          end
        end

        # sleep for a configured amount of time.
        #
        # BUT WHY? at present we're having an issue with Ceph backed preservation storage that plays out something like:
        # * a preservation_robots worker finishes writing a new version of a Moab to its druid tree in the storage trunk, from a bag
        #   left in the deposit trunk.
        # * the preservation_robots worker signals preservation_catalog that it has finished updating the Moab (update_catalog, above).
        # * preservation_catalog, running on a different VM from the preservation_robots worker, attempts to read the Moab contents.
        #   * unfortunately, the Ceph MDS (Metadata Server) that responds to a preservation_catalog VM sometimes lags in learning that the
        #     preservation_robots VM that wrote the Moab has given up the original write lock, and then preservation_catalog effectively
        #     has trouble fully reading the contents of the new Moab version.  In our experience, a locked file will sometimes not become
        #     available to pres cat until the MDS instance is restarted.  Though sometimes it becomes available on its own tens of seconds later.
        #   * usually this happens when trying to read and zip the Moab version for cloud replication in a later async pres cat job.  but sometimes
        #     it happens when the more cursory version check on the pres cat side of the update_catalog API call is executed.
        #   * so there's an argument for putting the delay on the other side, in the API implementation.  but putting a multi-second delay
        #     in something that's already an asynchronous job feels less icky than putting it in a REST method implementation, and there's
        #     inescapable interplay here between pres robots and pres cat anyway.
        # we hope to figure out a way to further tune our Ceph setup so that this delay is no longer needed.
        def wait_as_needed
          sleep(Settings.hacks.update_catalog_delay_seconds)
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
