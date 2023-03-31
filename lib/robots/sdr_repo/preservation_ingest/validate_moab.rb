# frozen_string_literal: true

# Robot package to run under multiplexing infrastructure
module Robots
  # Use DorRepo/SdrRepo to match the workflow repo (and avoid name collision with Dor module)
  module SdrRepo
    # The workflow package name - match the actual workflow name, minus ending WF (using CamelCase)
    module PreservationIngest
      # Robot for validating Moab object
      class ValidateMoab < Base
        ROBOT_NAME = 'validate-moab'

        def initialize
          super(WORKFLOW_NAME, ROBOT_NAME)
        end

        def perform_work
          validate_moab
          # workflow logging done in PreservationCatalog (by ValidateMoabJob)
          LyberCore::ReturnState.new(status: :noop, note: 'Initiated validate-moab API call.')
        end

        private

        # @note Why call out to preservation_catalog to actually perform this WF step's checksum validation?
        # We want the validation to run from another VM, and pres cat already handles replication and regularly
        # scheduled fixity checking. Validating from a different VM catches a couple failure modes we've seen:
        # 1) Temporary inability of the pres cat VMs' Ceph clients to read data recently written by
        #    a preservation_robots Ceph client.
        # 2) preservation_robots UpdateMoab gets control back as if the new Moab version has been fully written, when
        #    in fact CephFS* may not have fully flushed its buffer to the underlying object store.  If the Ceph client loses
        #    connectivity or the VM is rebooted before the buffer is flushed, unflushed buffered data will actually be
        #    lost (though 0s may be written as placeholders, leading to files that seem complete at first glance).
        # Running checksum validation on the Moab version after the file write operation has returned to preservation_robots,
        # from a different VM's Ceph client, should catch either problem.
        # * POSIX-compliant file system built on top of Ceph’s distributed object store, see Ceph docs
        # ** A note in the preservation_catalog job that performs this work points to this explanation.  Please keep it up to
        #    date if this architecture changes.
        def validate_moab
          logger.debug("#{ROBOT_NAME} #{druid} starting")
          with_retries(max_tries: 3, handler: handler("Validating moab for #{druid}"),
                       rescue: Preservation::Client::ConnectionFailedError) do
            Preservation::Client.objects.validate_moab(druid: druid)
          end
        end
      end
    end
  end
end
