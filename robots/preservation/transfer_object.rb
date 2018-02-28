
module Preservation
  # Robot for transferring objects from the DOR export area to the Moab object deposit area
  class TransferObject < Base
    ROBOT_NAME = 'transfer-object'.freeze

    def initialize(opts = {})
      super(REPOSITORY, WORKFLOW_NAME, ROBOT_NAME, opts)
    end

    attr_reader :druid

    def perform(druid)
      @druid = druid
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
      prereqs_for_transfer
      deposit_dir = prepare_deposit_dir
      Base.execute_shell_command(tarpipe_command(deposit_dir))
    rescue StandardError => e
      raise(ItemError, "Error transferring object: #{e.message}")
    end

    def prereqs_for_transfer
      verify_accesssion_wf_step_completed
      verify_version_metadata
    end

    def verify_accesssion_wf_step_completed
      accession_status = workflow_service.get_workflow_status('dor', druid, 'accessionWF', 'sdr-ingest-transfer')
      err_msg = "accessionWF:sdr-ingest-transfer status is #{accession_status}"
      raise(ItemError, err_msg) unless accession_status == 'completed'
    end

    VERSION_METADATA_PATH_SUFFIX = '/data/metadata/versionMetadata.xml'.freeze

    def verify_version_metadata
      vm_path = File.join(Dor::Config.transfer_object.input_dir, bare_druid, VERSION_METADATA_PATH_SUFFIX)
      cmd = "if ssh #{Dor::Config.transfer_object.dor_host} test -e #{vm_path}; then echo yes; else echo no; fi"
      raise(ItemError, "#{vm_path} not found") if Base.execute_shell_command(cmd) == 'no'
    end

    def prepare_deposit_dir
      moab_object = Stanford::StorageServices.find_storage_object(druid, true)
      deposit_bag_pathname = moab_object.deposit_bag_pathname
      LyberCore::Log.debug("deposit bag pathname is : #{deposit_bag_pathname}")
      deposit_dir = deposit_bag_pathname.parent
      if deposit_bag_pathname.exist?
        remove_bag(deposit_bag_pathname)
      else
        deposit_dir.mkpath
      end
      deposit_dir
    end

    def remove_bag(bag_pathname)
      tries ||= 3
      bag_pathname.rmtree
    rescue StandardError => e
      retry if (tries -= 1).positive?
      raise(ItemError, "Failed cleanup (3 attempts) for #{bag_pathname}: #{e.message}")
    end

    # @see http://en.wikipedia.org/wiki/User:Chdev/tarpipe
    # ssh user@remotehost "tar -cf - srcdir | tar -C destdir -xf -
    # Note that symbolic links from /dor/export to /dor/workspace get translated into real files by use of --dereference
    def tarpipe_command(deposit_dir)
      "ssh #{Dor::Config.transfer_object.dor_host} " \
        '"tar -C ' + "#{Dor::Config.transfer_object.input_dir} --dereference -cf - #{bare_druid}" + ' "' \
        " | tar -C #{deposit_dir} -xf -"
    end

    def bare_druid
      druid.sub('druid:', '')
    end
  end
end
