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

        RETRIES = 5
        WAIT = 30 # seconds

        def initialize
          super(WORKFLOW_NAME, ROBOT_NAME)
        end

        def perform_work
          # TODO: alternative idea for making pres robots multi-plexable...
          # since the reads and writes that might suffer from networked
          # file system lag are all in transfer_object, validate_bag, and update_moab;
          # and since those are a sequence of dependencies, what about collapsing
          # them into one job?
          # yet another approach: just beef up the one pres robots VM and add worker threads or processes.
          # consult with ops about this?  query WF DB to see average run time of the relevant steps?  or count
          # of times that get close to hitting some very long runtime threshold?
          # yet another approach: NFS mount can be setup so that these lag problems don't happen, but reading/writing
          # is maybe way slower... would this be acceptable?  is this a setting on every mount point, or just a setting
          # on servers that write?  like, is it flush related?  since pres cat is RO, maybe the change could be limited to
          # pres bots VMs.
          # also: use claude for high level meta advice, see argo-b3 for agent files that point to other gems/deps for context,
          # and claude is good about looking at deps and going out to get context.  can also ask claude what it needs to
          # give a good answer.
          # also: draft up the collapsing-workflow-steps-into-one approach to see how it feels and whether it's an improvemnt or
          # a mess.
          with_retry { verify_version_metadata }
          prepare_deposit_dir
          with_retry { transfer_bag }
        rescue StandardError => e
          raise ItemError, "Error transferring bag (via #{Settings.transfer_object&.from_dir}) for #{druid}: #{e.message}"
        end

        VERSION_METADATA_PATH_SUFFIX = '/data/metadata/versionMetadata.xml'

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
      end
    end
  end
end
