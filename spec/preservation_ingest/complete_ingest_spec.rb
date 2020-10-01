describe Robots::SdrRepo::PreservationIngest::CompleteIngest do
  let(:bare_druid) { 'jc837rq9922' }
  let(:druid) { "druid:#{bare_druid}" }
  let(:spec_dir) { File.join(File.dirname(__FILE__), '..') }
  let(:deposit_dir_pathname) { Pathname(File.join(spec_dir, 'fixtures', 'deposit', 'complete-ingest')) }
  let(:deposit_bag_pathname) { Pathname(File.join(deposit_dir_pathname, bare_druid)) }
  let(:mock_moab_pathname) { Pathname(File.realpath(File.join(spec_dir, 'fixtures', 'sdr2objects', 'bz', '514', 'sm', '9647', 'bz514sm9647'))) }
  let(:mock_storage_object) { instance_double(Moab::StorageObject, deposit_bag_pathname: deposit_bag_pathname, object_pathname: mock_moab_pathname) }
  let(:mock_storage_objects) { [mock_storage_object] }
  let(:this_robot) { described_class.new }

  describe '#perform' do
    before do
      allow(deposit_bag_pathname).to receive(:rmtree)
      allow(Moab::StorageServices).to receive(:search_storage_objects).and_return(mock_storage_objects)
      allow(Moab::StorageServices).to receive(:find_storage_object).and_return(mock_storage_object)
      FileUtils.mkdir_p(deposit_bag_pathname)
      FileUtils.touch(deposit_bag_pathname + 'bagit_file.txt')
    end

    after do
      deposit_dir_pathname.rmtree if deposit_dir_pathname.exist?
    end

    it 'raises ItemError if it fails to remove the deposit bag' do
      expect(deposit_bag_pathname.exist?).to be true
      expect(deposit_bag_pathname).to receive(:rmtree).and_raise(StandardError, 'rmtree failed')
      exp_msg = Regexp.escape("Error completing ingest for #{druid}: failed to remove deposit bag (#{deposit_bag_pathname}): rmtree failed")
      expect { this_robot.perform(druid) }.to raise_error(Robots::SdrRepo::PreservationIngest::ItemError, a_string_matching(exp_msg))
      expect(deposit_bag_pathname.exist?).to be true
    end

    context 'if it fails to update the accessionWF sdr-ingest-received step' do
      before do
        allow(this_robot.workflow_service).to receive(:update_status).and_raise(Dor::WorkflowException.new('foo'))
      end

      it 'raises ItemError' do
        exp_msg = Regexp.escape("Error completing ingest for #{druid}: failed to update accessionWF:sdr-ingest-received to completed: ") + '.*foo'
        expect { this_robot.perform(druid) }.to raise_error(Robots::SdrRepo::PreservationIngest::ItemError, a_string_matching(exp_msg))
      end
    end

    it 'removes the deposit bag and updates the accessionWF when no errors are raised' do
      expect(deposit_bag_pathname).to receive(:rmtree)
      expect(this_robot.workflow_service).to receive(:update_status)
        .with(druid: druid,
              workflow: 'accessionWF',
              process: 'sdr-ingest-received',
              status: 'completed',
              elapsed: 1,
              note: String)
      expect { this_robot.perform(druid) }.not_to raise_error
    end

    context 'attempts to stat the contents of the moab directory' do
      let(:bare_druid) { 'bz514sm9647' }

      let(:moab_file_and_dir_list) do
        %w[
          fixtures/sdr2objects/bz/514/sm/9647/bz514sm9647
          fixtures/sdr2objects/bz/514/sm/9647/bz514sm9647/v0001
          fixtures/sdr2objects/bz/514/sm/9647/bz514sm9647/v0001/data
          fixtures/sdr2objects/bz/514/sm/9647/bz514sm9647/v0001/data/content
          fixtures/sdr2objects/bz/514/sm/9647/bz514sm9647/v0001/data/content/SC1258_FUR_032a.jpg
          fixtures/sdr2objects/bz/514/sm/9647/bz514sm9647/v0001/data/metadata
          fixtures/sdr2objects/bz/514/sm/9647/bz514sm9647/v0001/data/metadata/contentMetadata.xml
          fixtures/sdr2objects/bz/514/sm/9647/bz514sm9647/v0001/data/metadata/descMetadata.xml
          fixtures/sdr2objects/bz/514/sm/9647/bz514sm9647/v0001/data/metadata/identityMetadata.xml
          fixtures/sdr2objects/bz/514/sm/9647/bz514sm9647/v0001/data/metadata/provenanceMetadata.xml
          fixtures/sdr2objects/bz/514/sm/9647/bz514sm9647/v0001/data/metadata/relationshipMetadata.xml
          fixtures/sdr2objects/bz/514/sm/9647/bz514sm9647/v0001/data/metadata/rightsMetadata.xml
          fixtures/sdr2objects/bz/514/sm/9647/bz514sm9647/v0001/data/metadata/technicalMetadata.xml
          fixtures/sdr2objects/bz/514/sm/9647/bz514sm9647/v0001/data/metadata/versionMetadata.xml
          fixtures/sdr2objects/bz/514/sm/9647/bz514sm9647/v0001/data/metadata/workflows.xml
          fixtures/sdr2objects/bz/514/sm/9647/bz514sm9647/v0001/manifests
          fixtures/sdr2objects/bz/514/sm/9647/bz514sm9647/v0001/manifests/fileInventoryDifference.xml
          fixtures/sdr2objects/bz/514/sm/9647/bz514sm9647/v0001/manifests/manifestInventory.xml
          fixtures/sdr2objects/bz/514/sm/9647/bz514sm9647/v0001/manifests/signatureCatalog.xml
          fixtures/sdr2objects/bz/514/sm/9647/bz514sm9647/v0001/manifests/versionAdditions.xml
          fixtures/sdr2objects/bz/514/sm/9647/bz514sm9647/v0001/manifests/versionInventory.xml
        ]
      end

      it 'walks the moab directory and stats each file and dir contained within the moab' do
        # using #ordered is typically to be avoided, but we want to make sure walking the moab happens
        # after removing the deposit bag
        expect(deposit_bag_pathname).to receive(:rmtree).ordered
        expect(Find).to receive(:find).with(mock_moab_pathname).ordered.and_call_original

        # File.realpath will return a string representing "the real (absolute) pathname of pathname in the actual filesystem
        # not containing symlinks or useless dots" (see File class ruby docs).  this makes it easier to match the exact path
        # without worrying about absolute path differences between different dev laptops or laptops and CI (while also allowing
        # an exact match on path without just matching a substring).
        moab_file_and_dir_list.each { |path_str| expect(File).to receive(:stat).with(File.realpath(File.join(spec_dir, path_str))) }
        expect(this_robot.workflow_service).to receive(:update_status)
        this_robot.perform(druid)
      end

      it 'raises an error if one of the files or directories in the moab is unreadable at the moment it is checked' do
        v1_version_md_path_str = 'fixtures/sdr2objects/bz/514/sm/9647/bz514sm9647/v0001/data/metadata/versionMetadata.xml'
        read_err_msg = 'Permission denied @ rb_sysopen'
        exp_msg = /Error completing ingest for druid:bz514sm9647:.*#{read_err_msg}/

        allow(File).to receive(:stat)
        allow(File).to receive(:stat).with(File.realpath(File.join(spec_dir, v1_version_md_path_str))).and_raise(Errno::EACCES, read_err_msg)

        expect { this_robot.perform(druid) }.to raise_error(Robots::SdrRepo::PreservationIngest::ItemError, a_string_matching(exp_msg))
      end
    end
  end
end
