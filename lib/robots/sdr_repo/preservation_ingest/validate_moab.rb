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
