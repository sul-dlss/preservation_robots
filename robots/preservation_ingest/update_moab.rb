# Robot package to run under multiplexing infrastructure
module Robots
  # Use DorRepo/SdrRepo to match the workflow repo (and avoid name collision with Dor module)
  module SdrRepo
    # The workflow package name - match the actual workflow name, minus ending WF (using CamelCase)
    module PreservationIngest
      # Robot for ingesting deposit bag into Moab object (creating a new version)
      class UpdateMoab < Base
        ROBOT_NAME = 'update-moab'.freeze

        def initialize(opts={})
          super(REPOSITORY, WORKFLOW_NAME, ROBOT_NAME, opts)
        end

        def perform(druid)
          LyberCore::Log.debug("#{ROBOT_NAME} #{druid} starting")
          storage_object = Moab::StorageServices.find_storage_object(druid, true)
          storage_object.object_pathname.mkpath
          update_moab(storage_object)
        end

        private

        def update_moab(storage_object)
          new_version = storage_object.ingest_bag
          result = new_version.verify_version_storage
          return if result.verified
          LyberCore::Log.info result.to_json(false)
          raise(ItemError, "Failed verification for #{result.entity}")
        end
      end
    end
  end
end
