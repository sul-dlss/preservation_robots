module Preservation
  # Robot for validating bag in the Moab object deposit area
  class ValidateBag < Base
    ROBOT_NAME = 'validate-bag'.freeze

    def initialize(opts = {})
      super(REPOSITORY, WORKFLOW_NAME, 'validate-bag', opts)
    end

    attr_reader :druid

    def perform(druid)
      @druid = druid
      validate_bag
    end

    private

    def validate_bag
      LyberCore::Log.debug("#{ROBOT_NAME} #{druid} starting")
      moab_object = Stanford::StorageServices.find_storage_object(druid, true)
      deposit_bag_validator = Moab::DepositBagValidator.new(moab_object)
      validation_errors = deposit_bag_validator.validation_errors
      raise(ItemError, "Bag validation failure(s): #{validation_errors}") if validation_errors.any?
    end
  end
end
