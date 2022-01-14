# frozen_string_literal: true

# Robot package to run under multiplexing infrastructure
module Robots
  # Use DorRepo/SdrRepo to match the workflow repo (and avoid name collision with Dor module)
  module SdrRepo
    # The workflow package name - match the actual workflow name, minus ending WF (using CamelCase)
    module PreservationIngest
      # Robot for validating bag in the Moab object deposit area
      class ValidateBag < Base
        ROBOT_NAME = 'validate-bag'

        def initialize
          super(WORKFLOW_NAME, ROBOT_NAME)
        end

        attr_reader :druid

        def perform(druid)
          @druid = druid # for base class attr_accessor
          validate_bag
        end

        private

        def validate_bag
          LyberCore::Log.debug("#{ROBOT_NAME} #{druid} starting")
          deposit_bag_validator = DepositBagValidator.new(moab_object)
          validation_errors = deposit_bag_validator.validation_errors
          raise(ItemError, "Bag validation failure(s) for #{druid}: #{validation_errors}") if validation_errors.any?
        end
      end
    end
  end
end
