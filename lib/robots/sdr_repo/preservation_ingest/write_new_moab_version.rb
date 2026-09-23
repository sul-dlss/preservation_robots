# frozen_string_literal: true

require 'open3'

# Robot package to run under multiplexing infrastructure
module Robots
  # Use DorRepo/SdrRepo to match the workflow repo (and avoid name collision with Dor module)
  module SdrRepo
    # The workflow package name - match the actual workflow name, minus ending WF (using CamelCase)
    module PreservationIngest
      # Robot that writes a new Moab version: it transfers the deposit bag from the DOR export area to the
      # Moab object deposit area, validates that deposit bag, and then ingests it as a new Moab version.
      #
      # These three operations used to be three separate workflow steps (transfer-object, validate-bag,
      # update-moab).  They are performed by a single step because each depends on the file system writes
      # made by the preceding one, and reads of those writes may lag when they happen from a different VM's
      # client of the networked file system.  Doing all of this work in one step keeps the writes and the
      # reads that depend on them on the same VM, which allows multiple preservation_robots VMs to run at
      # the same time.
      class WriteNewMoabVersion < Base
        ROBOT_NAME = 'write-new-moab-version'

        RETRIES = 5
        WAIT = 30 # seconds

        VERSION_METADATA_PATH_SUFFIX = '/data/metadata/versionMetadata.xml'

        def initialize
          super(WORKFLOW_NAME, ROBOT_NAME)
        end

        def perform_work
          logger.debug("#{ROBOT_NAME} #{druid} starting")
          verify_prepare_and_transfer
          validate_bag
          update_moab
        end

        private

        def with_retry
          tries ||= 0
          yield
        rescue StandardError
          if (tries += 1) <= RETRIES
            sleep tries * WAIT
            retry
          end
          raise
        end

        # transfer the deposit bag from the DOR export area to the Moab object deposit area

        def verify_prepare_and_transfer
          with_retry { verify_version_metadata }
          prepare_deposit_dir
          with_retry { transfer_bag }
        rescue StandardError => e
          raise ItemError, "Error transferring bag (via #{Settings.transfer_object&.from_dir}) for #{druid}: #{e.message}"
        end

        # Check to see if the bag exists in the workspace directory before starting
        def verify_version_metadata
          raise ItemError, "#{version_metadata_path} not found" unless version_metadata_path.exist?
        end

        def version_metadata_path
          Pathname.new(
            File.join(from_dir, bare_druid, VERSION_METADATA_PATH_SUFFIX)
          )
        end

        def prepare_deposit_dir
          logger.debug("deposit bag pathname is: #{deposit_bag_pathname}")
          if deposit_bag_pathname.exist?
            deposit_bag_pathname.rmtree
          else
            deposit_dir.mkpath
          end
        rescue StandardError => e
          raise ItemError, "Failed preparation of deposit dir #{deposit_bag_pathname}: #{e.message}"
        end

        def deposit_dir
          deposit_bag_pathname.parent
        end

        def from_dir
          Settings.transfer_object.from_dir
        end

        def transfer_bag
          # Why shell out instead of using a Ruby FileUtils-based approach?
          # FileUtils.cp_r only allows for dereferencing the root of what's copied; it
          # doesn't recursively dereference symlinks, which is the expected behavior.
          transfer_command = "cp -rL #{File.join(from_dir, bare_druid)} #{deposit_dir}"
          Open3.popen2e(transfer_command) do |_stdin, stdout_and_stderr, wait_thr|
            output = stdout_and_stderr.read
            status = wait_thr.value

            if status.nil? || !status.success?
              deposit_bag_pathname.rmtree if deposit_bag_pathname.exist?
              raise "Transfering bag for #{druid} to preservation failed. STDOUT = #{output}"
            end
          end
        end

        def bare_druid
          druid.delete_prefix('druid:')
        end

        # validate the bag that was just transferred to the Moab object deposit area

        def validate_bag
          logger.debug("#{ROBOT_NAME} #{druid} validating deposit bag")
          deposit_bag_validator = DepositBagValidator.new(moab_object)
          validation_errors = deposit_bag_validator.validation_errors
          raise(ItemError, "Bag validation failure(s) for #{druid}: #{validation_errors}") if validation_errors.any?
        end

        # ingest the validated deposit bag into the Moab object as a new version

        def update_moab
          logger.debug("#{ROBOT_NAME} #{druid} ingesting deposit bag into moab")
          new_version = moab_object.ingest_bag(use_links: false)
          result = new_version.verify_version_storage
          return if result.verified

          logger.info result.to_json(false)
          raise(ItemError, "Failed verification for #{result.entity}")
        end
      end
    end
  end
end
