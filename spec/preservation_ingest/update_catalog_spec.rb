# rubocop:disable Metrics/BlockLength

RSpec.describe Robots::SdrRepo::PreservationIngest::UpdateCatalog do
  subject(:update_catalog_obj) { described_class.new }

  let(:bare_druid) { 'bj102hs9687' }
  let(:druid) { "druid:#{bare_druid}" }

  let(:size) { 2342 }
  let(:version) { 1 }
  let(:strg_root) { 'some/storage/location/from/endpoint/table' }
  let(:url) { 'http://localhost:3000' }
  let(:args) do
    {
      druid: bare_druid,
      incoming_version: version,
      incoming_size: size,
      storage_location: strg_root,
      checksums_validated: true
    }
  end
  let(:mock_storage_object) do
    instance_double(Moab::StorageObject, deposit_bag_pathname: deposit_bag_pathname, object_pathname: mock_moab_pathname, size: size, storage_root: strg_root, current_version_id: version)
  end
  let(:mock_storage_objects) { [mock_storage_object] }

  let(:spec_dir) { File.join(File.dirname(__FILE__), '..') }
  let(:deposit_dir_pathname) { Pathname(File.join(spec_dir, 'fixtures', 'deposit', 'update-catalog')) }
  let(:deposit_bag_pathname) { Pathname(File.join(deposit_dir_pathname, bare_druid)) }
  let(:mock_moab_pathname) { Pathname(File.realpath(File.join(spec_dir, 'fixtures', 'sdr2objects', 'bz', '514', 'sm', '9647', 'bz514sm9647'))) }

  before do
    allow(Moab::StorageServices).to receive(:search_storage_objects).and_return(mock_storage_objects)
    allow(Moab::StorageServices).to receive(:find_storage_object).and_return(mock_storage_object)
  end

  describe '#perform' do
    before do
      allow(LyberCore::Log).to receive(:debug).with(any_args)
      allow(deposit_bag_pathname).to receive(:rmtree)
      allow(Moab::StorageServices).to receive(:search_storage_objects).and_return(mock_storage_objects)
      allow(Moab::StorageServices).to receive(:find_storage_object).and_return(mock_storage_object)
      FileUtils.mkdir_p(deposit_bag_pathname)
      FileUtils.touch("#{deposit_bag_pathname}bagit_file.txt")
    end

    after do
      deposit_dir_pathname.rmtree if deposit_dir_pathname.exist?
    end

    it 'raises ItemError if it fails to remove the deposit bag' do
      expect(deposit_bag_pathname.exist?).to be true
      expect(deposit_bag_pathname).to receive(:rmtree).and_raise(StandardError, 'rmtree failed')
      exp_msg = Regexp.escape("Error completing ingest for #{druid}: failed to remove deposit bag (#{deposit_bag_pathname}): rmtree failed")
      expect { update_catalog_obj.perform(druid) }.to raise_error(Robots::SdrRepo::PreservationIngest::ItemError, a_string_matching(exp_msg))
      expect(deposit_bag_pathname.exist?).to be true
    end

    context 'object is new' do
      context 'when the call is successful' do
        before do
          stub_request(:post, 'http://localhost:3000/v1/catalog')
            .with(
              body: {
                'checksums_validated' => 'true', 'druid' => 'bj102hs9687',
                'incoming_size' => '2342', 'incoming_version' => '1',
                'storage_location' => 'some/storage/location/from/endpoint/table'
              }
            )
            .to_return(status: 200, body: '', headers: {})
        end

        it 'removes the deposit bag and POST to /v1/catalog' do
          expect(deposit_bag_pathname).to receive(:rmtree)
          update_catalog_obj.perform(bare_druid)
        end
      end

      context 'removes the deposit bag and when HTTP fails twice' do
        before do
          stub_request(:post, 'http://localhost:3000/v1/catalog')
            .with(
              body: {
                'checksums_validated' => 'true', 'druid' => 'bj102hs9687',
                'incoming_size' => '2342', 'incoming_version' => '1',
                'storage_location' => 'some/storage/location/from/endpoint/table'
              }
            )
            .to_return(
              { status: 500, body: '', headers: {} },
              { status: 500, body: '', headers: {} },
              status: 200, body: '', headers: {}
            )
        end

        it 'succeeds' do
          allow(LyberCore::Log).to receive(:warn).twice
          expect(deposit_bag_pathname).to receive(:rmtree)
          update_catalog_obj.perform(bare_druid)
        end
      end

      context 'when HTTP fails thrice' do
        before do
          stub_request(:post, 'http://localhost:3000/v1/catalog')
            .with(
              body: {
                'checksums_validated' => 'true', 'druid' => 'bj102hs9687',
                'incoming_size' => '2342', 'incoming_version' => '1',
                'storage_location' => 'some/storage/location/from/endpoint/table'
              }
            )
            .to_return(
              { status: 500, body: '', headers: {} },
              { status: 500, body: '', headers: {} },
              status: 500, body: '', headers: {}
            )
        end

        it 'removes the deposit bag and fails' do
          expect(deposit_bag_pathname).to receive(:rmtree)
          expect { update_catalog_obj.perform(bare_druid) }.to raise_error(Preservation::Client::UnexpectedResponseError)
        end
      end
    end

    context 'object already exists' do
      let(:version) { 3 }

      before do
        stub_request(:patch, 'http://localhost:3000/v1/catalog/bj102hs9687')
          .with(
            body: {
              'checksums_validated' => 'true', 'druid' => 'bj102hs9687',
              'incoming_size' => '2342', 'incoming_version' => '3',
              'storage_location' => 'some/storage/location/from/endpoint/table'
            }
          )
          .to_return(status: 200, body: '', headers: {})
      end

      it 'removes the deposit bag and PATCH to /v1/catalog/:druid' do
        expect(deposit_bag_pathname).to receive(:rmtree)
        update_catalog_obj.perform(bare_druid)
      end
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

      before do
        stub_request(:post, 'http://localhost:3000/v1/catalog')
          .with(
            body: {
              'checksums_validated' => 'true', 'druid' => bare_druid,
              'incoming_size' => '2342', 'incoming_version' => '1',
              'storage_location' => 'some/storage/location/from/endpoint/table'
            }
          )
          .to_return(status: 200, body: '', headers: {})
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
        update_catalog_obj.perform(bare_druid)
      end

      it 'raises an error if one of the files or directories in the moab is unreadable at the moment it is checked' do
        v1_version_md_path_str = 'fixtures/sdr2objects/bz/514/sm/9647/bz514sm9647/v0001/data/metadata/versionMetadata.xml'
        read_err_msg = 'Permission denied @ rb_sysopen'
        exp_msg = /Error completing ingest for bz514sm9647:.*#{read_err_msg}/

        allow(File).to receive(:stat)
        allow(File).to receive(:stat).with(File.realpath(File.join(spec_dir, v1_version_md_path_str))).and_raise(Errno::EACCES, read_err_msg)

        expect { update_catalog_obj.perform(bare_druid) }.to raise_error(Robots::SdrRepo::PreservationIngest::ItemError, a_string_matching(exp_msg))
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
