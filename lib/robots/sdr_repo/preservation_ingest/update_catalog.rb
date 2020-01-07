require 'faraday'
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

        def handler
          update_cat_msg = "Updating preservation catalog for #{druid}"
          proc do |exception, attempt_number, _total_delay|
            LyberCore::Log.warn("#{update_cat_msg}: try #{attempt_number} failed: #{exception.message}")
            raise exception if attempt_number == 3
          end
        end

        def update_catalog
          with_retries(max_tries: 3, handler: handler, rescue: Preservation::Client::Error) do
            Preservation::Client.update(druid: druid,
                                        version: moab_object.current_version_id,
                                        size: moab_object.size,
                                        storage_location: moab_object.storage_root)
          end
        end
      end
    end
  end
end
