# frozen_string_literal: true

# Robot package to run under multiplexing infrastructure
module Robots
  # Use DorRepo/SdrRepo to match the workflow repo (and avoid name collision with Dor module)
  module SdrRepo
    # The workflow package name - match the actual workflow name, minus ending WF (using CamelCase)
    module PreservationIngest
      # Base class for all preservation robots
      class Base < LyberCore::Robot
        WORKFLOW_NAME = 'preservationIngestWF'

        private

        # handle retries errors
        def handler(msg)
          proc do |exception, attempt_number, _total_delay|
            logger.warn("#{msg}: try #{attempt_number} failed: #{exception.message}")
            raise exception if attempt_number == 3
          end
        end

        def moab_object
          @moab_object ||= Stanford::StorageServices.find_storage_object(druid, true)
        end

        def deposit_bag_pathname
          @deposit_bag_pathname ||= moab_object.deposit_bag_pathname
        end
      end
    end
  end
end
