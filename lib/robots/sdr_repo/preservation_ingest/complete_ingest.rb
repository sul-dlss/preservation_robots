# frozen_string_literal: true

# Robot package to run under multiplexing infrastructure
module Robots
  # Use DorRepo/SdrRepo to match the workflow repo (and avoid name collision with Dor module)
  module SdrRepo
    # The workflow package name - match the actual workflow name, minus ending WF (using CamelCase)
    module PreservationIngest
      # Clean up workspace; transfer control back to accessioning by updating accessionWF sdr-ingest-received step
      class CompleteIngest < Base
        ROBOT_NAME = 'complete-ingest'

        def initialize
          super(WORKFLOW_NAME, ROBOT_NAME)
        end

        def perform_work
          logger.debug("#{ROBOT_NAME} #{druid} starting")
          complete_ingest
        end

        private

        def complete_ingest
          # common_accessioning workflow blocks after it queues up preservation workflow for object
          #   until it receives this signal
          object_client.workflow('accessionWF').process('sdr-ingest-received').update(
            status: 'completed',
            note: "#{WORKFLOW_NAME} completed on #{Socket.gethostname}"
          )
        rescue Dor::Services::Client::Error => e
          errmsg = "Error completing ingest for #{druid}: failed to update " \
                   "accessionWF:sdr-ingest-received to completed: #{e.message}\n#{e.backtrace.join('\n')}"
          logger.error(errmsg)
          raise(ItemError, errmsg)
        end
      end
    end
  end
end
