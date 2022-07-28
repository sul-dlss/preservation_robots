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

        def perform(druid)
          @druid = druid # for base class attr_accessor
          transfer_object
        end

        private

        # Transfer and untar the object from the DOR export area to the SDR deposit area.
        #   Note: POSIX tar has a limit of 100 chars in a filename
        #     some implementations of gnu TAR work around this by adding a ././@LongLink file containing the full name
        #     See: http://www.delorie.com/gnu/docs/tar/tar_114.html
        #      http://stackoverflow.com/questions/2078778/what-exactly-is-the-gnu-tar-longlink-trick
        #      http://www.gnu.org/software/tar/manual/html_section/Portability.html
        #   Also, beware of incompatibilities between BSD tar and other TAR formats
        #     regarding the handling of vendor extended attributes.
        #     See: http://xorl.wordpress.com/2012/05/15/admin-mistakes-gnu-bsd-tar-and-posix-compatibility/
        def transfer_object
          LyberCore::Log.debug("#{ROBOT_NAME} #{druid} starting")
          verify_version_metadata
          prepare_deposit_dir
          transfer_bag
        rescue StandardError => e
          raise(ItemError, "Error transferring bag (via #{Settings&.transfer_object&.from_host}) for #{druid}: #{e.message}")
        end

        VERSION_METADATA_PATH_SUFFIX = '/data/metadata/versionMetadata.xml'

        # Check to see if the bag exists in the workspace directory before starting
        def verify_version_metadata
          version_metadata_path = File.join(from_dir, bare_druid, VERSION_METADATA_PATH_SUFFIX)
          cmd = "if ssh #{from_host} test -e #{version_metadata_path}; then echo yes; else echo no; fi"
          raise(ItemError, "#{version_metadata_path} not found") if self.class.execute_shell_command(cmd) == 'no'
        end

        def prepare_deposit_dir
          LyberCore::Log.debug("deposit bag pathname is: #{deposit_bag_pathname}")
          if deposit_bag_pathname.exist?
            deposit_bag_pathname.rmtree
          else
            deposit_dir.mkpath
          end
        rescue StandardError => e
          raise(ItemError, "Failed preparation of deposit dir #{deposit_bag_pathname}: #{e.message}")
        end

        def deposit_dir
          deposit_bag_pathname.parent
        end

        def from_host
          Settings.transfer_object.from_host
        end

        def from_dir
          Settings.transfer_object.from_dir
        end

        # @see http://en.wikipedia.org/wiki/User:Chdev/tarpipe
        # ssh user@remotehost "tar -cf - srcdir | tar -C destdir -xf -
        # Note that symbolic links from /dor/export to /dor/workspace get
        #  translated into real files by use of --dereference
        # if command doesn't exit with 0, grabs stdout and stderr and puts them in ruby exception message
        def transfer_bag
          ssh = "ssh #{from_host} \"tar -C #{from_dir} --dereference -cf - #{bare_druid} \""
          untar = "tar -C #{deposit_dir} -xf -"

          # If you get an error here it might be a firewall issue between
          # your preservation robots app and the configured
          # Settings.transfer.from_host (dor-services-worker)
          #
          # This has also been known to fail when the ssh keys in
          # ~/.ssh/known_hosts includes an invalid public key for the
          # dor-services-worker, or if a user is required to authorize
          # the addition of the new public key.

          Open3.pipeline_r(ssh, untar) do |last_stdout, wait_threads|
            stdout = last_stdout.read # Blocks until complete
            raise "Transfering bag for #{druid} to preservation failed. STDOUT = #{stdout}" unless wait_threads.map(&:value).all?(&:success?)
          end
        end

        def bare_druid
          druid.delete_prefix('druid:')
        end
      end
    end
  end
end
