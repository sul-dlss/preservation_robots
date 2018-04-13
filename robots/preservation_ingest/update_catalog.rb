# Robot package to run under multiplexing infrastructure
module Robots
  # Use DorRepo/SdrRepo to match the workflow repo (and avoid name collision with Dor module)
  module SdrRepo
    # The workflow package name - match the actual workflow name, minus ending WF (using CamelCase)
    module PreservationIngest
      # what does this class do? FIXME
      class UpdateCatalog < Base
        ROBOT_NAME = 'update-catalog'.freeze

        def initialize(opts = {})
          super(REPOSITORY, WORKFLOW_NAME, ROBOT_NAME, opts)
        end

        def perform(druid)
          LyberCore::Log.debug("#{ROBOT_NAME} #{druid} starting")
          @druid = druid # for base class attr_accessor
          update_catalog
        end

        private

        def update_catalog
          size = moab_object.size
          storage_location = moab_object.storage_root
          latest_version_id = moab_object.current_version_id
          args = {
            druid: druid,
            incoming_version: latest_version_id,
            incoming_size: size,
            storage_location: storage_location
          }
          response = conn.post '/catalog', args
          conn.patch "/catalog/#{druid}", args if response.status == 409
        end

        def conn
          @conn ||= Faraday.new(url: Settings.preservation_catalog.url)
        end
      end
    end
  end
end
