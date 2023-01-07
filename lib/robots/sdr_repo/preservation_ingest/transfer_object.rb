# frozen_string_literal: true

require 'open3'

# Robot package to run under multiplexing infrastructure
module Robots
  # Use DorRepo/SdrRepo to match the workflow repo (and avoid name collision with Dor module)
  module SdrRepo
    # The workflow package name - match the actual workflow name, minus ending WF (using CamelCase)
    module PreservationIngest
      # Robot transfers deposit bags from the DOR export area to the Moab object deposit area
      class TransferObject < Base
        ROBOT_NAME = 'transfer-object'

        def initialize
          super(WORKFLOW_NAME, ROBOT_NAME)
        end

        def perform_work
          transfer_object
        end

        private

        # Transfer the object from the DOR export area to the SDR deposit area.
        def transfer_object
          logger.debug("#{ROBOT_NAME} #{druid} starting")
          verify_version_metadata
          prepare_deposit_dir
          transfer_bag
        rescue StandardError => e
          raise ItemError, "Error transferring bag (via #{Settings.transfer_object&.from_dir}) for #{druid}: #{e.message}"
        end

        VERSION_METADATA_PATH_SUFFIX = '/data/metadata/versionMetadata.xml'

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

            raise "Transfering bag for #{druid} to preservation failed. STDOUT = #{output}" if status.nil? || !status.success?
          end
        end

        def bare_druid
          druid.delete_prefix('druid:')
        end
      end
    end
  end
end
