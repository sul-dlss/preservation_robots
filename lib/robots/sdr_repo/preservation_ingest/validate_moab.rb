# Robot package to run under multiplexing infrastructure
module Robots
  # Use DorRepo/SdrRepo to match the workflow repo (and avoid name collision with Dor module)
  module SdrRepo
    # The workflow package name - match the actual workflow name, minus ending WF (using CamelCase)
    module PreservationIngest
      # Robot for validating Moab object
      class ValidateMoab < Base
        ROBOT_NAME = 'validate-moab'.freeze

        def initialize(opts = {})
          super(WORKFLOW_NAME, ROBOT_NAME, opts)
        end

        def perform(druid)
          @druid = druid # for base class attr_accessor
          validate_moab
        end

        private

        def validate_moab
          LyberCore::Log.debug("#{ROBOT_NAME} #{druid} starting")
          with_retries(max_tries: 3, handler: handler, rescue: Preservation::Client::Error) do
            Preservation::Client.objects.validate_moab(druid: druid)
          end
        end

        def handler
          msg = "Validating moab for #{druid}"
          proc do |exception, attempt_number, _total_delay|
            LyberCore::Log.warn("#{msg}: try #{attempt_number} failed: #{exception.message}")
            raise exception if attempt_number == 3
          end
        end
      end
    end
  end
end
