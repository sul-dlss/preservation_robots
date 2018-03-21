
module Preservation
  # Robot either creates or updates moab version then places it into the Moab directory.
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
