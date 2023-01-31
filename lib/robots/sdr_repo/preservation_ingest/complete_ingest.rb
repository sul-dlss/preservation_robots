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
          update_accession_workflow
        end

        def update_accession_workflow
          workflow_service.update_status(druid: druid,
                                         workflow: 'accessionWF',
                                         process: 'sdr-ingest-received',
                                         status: 'completed',
                                         elapsed: 1,
                                         note: "#{WORKFLOW_NAME} completed on #{Socket.gethostname}")
        rescue Dor::WorkflowException => e
          errmsg = "Error completing ingest for #{druid}: failed to update " \
                   "accessionWF:sdr-ingest-received to completed: #{e.message}\n#{e.backtrace.join('\n')}"
          logger.error(errmsg)
          raise(ItemError, errmsg)
        end
      end
    end
  end
end
