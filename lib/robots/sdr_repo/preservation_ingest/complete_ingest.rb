# Robot package to run under multiplexing infrastructure
module Robots
  # Use DorRepo/SdrRepo to match the workflow repo (and avoid name collision with Dor module)
  module SdrRepo
    # The workflow package name - match the actual workflow name, minus ending WF (using CamelCase)
    module PreservationIngest
      # Clean up workspace; transfer control back to accessioning by updating accessionWF sdr-ingest-received step
      class CompleteIngest < Base
        ROBOT_NAME = 'complete-ingest'.freeze

        def initialize(opts = {})
          super(WORKFLOW_NAME, ROBOT_NAME, opts)
        end

        def perform(druid)
          LyberCore::Log.debug("#{ROBOT_NAME} #{druid} starting")
          @druid = druid # for base class attr_accessor
          complete_ingest
        end

        private

        def complete_ingest
          remove_deposit_bag
          # common_accessioning workflow blocks after it queues up preservation workflow for object
          #   until it receives this signal
          update_accession_workflow
        end

        def remove_deposit_bag
          rm_deposit_bag_safely_for_ceph
        rescue StandardError => e
          errmsg = "Error completing ingest for #{druid}: failed to remove deposit bag (#{deposit_bag_pathname}): " \
            "#{e.message}\n + e.backtrace.join('\n')"
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

        def update_accession_workflow
          workflow_service.update_status(druid: druid,
                                         workflow: 'accessionWF',
                                         process: 'sdr-ingest-received',
                                         status: 'completed',
                                         elapsed: 1,
                                         note: "#{WORKFLOW_NAME} completed on #{Socket.gethostname}")
        rescue Dor::WorkflowException => e
          errmsg = "Error completing ingest for #{druid}: failed to update " \
            "accessionWF:sdr-ingest-received to completed: #{e.message}\n#{e.backtrace.join('\n')}"
          LyberCore::Log.error(errmsg)
          raise(ItemError, errmsg)
        end
      end
    end
  end
end
