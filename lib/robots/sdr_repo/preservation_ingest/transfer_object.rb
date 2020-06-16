# Robot package to run under multiplexing infrastructure
module Robots
  # Use DorRepo/SdrRepo to match the workflow repo (and avoid name collision with Dor module)
  module SdrRepo
    # The workflow package name - match the actual workflow name, minus ending WF (using CamelCase)
    module PreservationIngest
      # Robot transfers deposit bags from the DOR export area to the Moab object deposit area
      class TransferObject < Base
        ROBOT_NAME = 'transfer-object'.freeze

        def initialize(opts = {})
          super(WORKFLOW_NAME, ROBOT_NAME, opts)
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
          deposit_dir = prepare_deposit_dir
          self.class.execute_shell_command(tarpipe_command(deposit_dir))
        rescue StandardError => e
          raise(ItemError, "Error transferring bag (via #{Settings&.transfer_object&.from_host}) for #{druid}: #{e.message}")
        end

        VERSION_METADATA_PATH_SUFFIX = '/data/metadata/versionMetadata.xml'.freeze

        def verify_version_metadata
          vm_path = File.join(Settings.transfer_object.from_dir, bare_druid, VERSION_METADATA_PATH_SUFFIX)
          cmd = "if ssh #{Settings.transfer_object.from_host} test -e #{vm_path}; then echo yes; else echo no; fi"
          raise(ItemError, "#{vm_path} not found") if self.class.execute_shell_command(cmd) == 'no'
        end

        def prepare_deposit_dir
          LyberCore::Log.debug("deposit bag pathname is: #{deposit_bag_pathname}")
          deposit_dir = deposit_bag_pathname.parent
          if deposit_bag_pathname.exist?
            deposit_bag_pathname.rmtree
          else
            deposit_dir.mkpath
          end
          deposit_dir
        rescue StandardError => e
          raise(ItemError, "Failed preparation of deposit dir #{deposit_bag_pathname}: #{e.message}")
        end

        # @see http://en.wikipedia.org/wiki/User:Chdev/tarpipe
        # ssh user@remotehost "tar -cf - srcdir | tar -C destdir -xf -
        # Note that symbolic links from /dor/export to /dor/workspace get
        #  translated into real files by use of --dereference
        def tarpipe_command(deposit_dir)
          "ssh #{Settings.transfer_object.from_host} " \
            '"tar -C ' + "#{Settings.transfer_object.from_dir} --dereference -cf - #{bare_druid}" + ' "' \
            " | tar -C #{deposit_dir} -xf -"
        end

        def bare_druid
          druid.sub('druid:', '')
        end
      end
    end
  end
end
