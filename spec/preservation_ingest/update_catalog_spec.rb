# frozen_string_literal: true

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
    instance_double(Moab::StorageObject,
                    deposit_bag_pathname: deposit_bag_pathname,
                    object_pathname: mock_moab_pathname,
                    size: size,
                    storage_root: strg_root,
                    current_version_id: version)
  end
  let(:spec_dir) { File.join(File.dirname(__FILE__), '..') }
  let(:deposit_dir_pathname) { Pathname(File.join(spec_dir, 'fixtures', 'deposit', 'update-catalog')) }
  let(:deposit_bag_pathname) { Pathname(File.join(deposit_dir_pathname, bare_druid)) }
  let(:mock_moab_pathname) { Pathname(File.realpath(File.join(spec_dir, 'fixtures', 'sdr2objects', 'bz', '514', 'sm', '9647', 'bz514sm9647'))) }

  describe '#perform' do
    before do
      allow(LyberCore::Log).to receive(:debug).with(any_args)
      allow(deposit_bag_pathname).to receive(:rmtree)
      allow(Moab::StorageServices).to receive(:find_storage_object).and_return(mock_storage_object)
      FileUtils.mkdir_p(deposit_bag_pathname)
      FileUtils.touch("#{deposit_bag_pathname}bagit_file.txt")
    end

    after do
      deposit_dir_pathname.rmtree if deposit_dir_pathname.exist?
    end

    context 'when the deposit bag still exists' do
      it 'raises ItemError if it fails to remove the deposit bag' do
        expect(deposit_bag_pathname.exist?).to be true
        rmtree_err_msg = 'rmtree failed with some weird permission error or something'
        allow(deposit_bag_pathname).to receive(:rmtree).and_raise(StandardError, rmtree_err_msg)
        base_err_msg = "Error completing ingest for #{druid}: failed to remove deposit bag (#{deposit_bag_pathname})"
        exp_msg_regexp = Regexp.escape("#{base_err_msg}: #{rmtree_err_msg}")
        expect { update_catalog_obj.perform(druid) }.to raise_error(Robots::SdrRepo::PreservationIngest::ItemError, a_string_matching(exp_msg_regexp))
        expect(deposit_bag_pathname.exist?).to be true
      end
    end

    context 'when the deposit bag has already been removed' do
      before do
        allow(deposit_bag_pathname).to receive(:rmtree).and_call_original
        deposit_bag_pathname.rmtree

        stub_request(:post, 'http://localhost:3000/v1/catalog')
          .with(
            body: {
              'checksums_validated' => 'true', 'druid' => 'druid:bj102hs9687',
              'incoming_size' => '2342', 'incoming_version' => '1',
              'storage_location' => 'some/storage/location/from/endpoint/table'
            }
          )
          .to_return(status: 200, body: '', headers: {})
      end

      it 'sends a honeybadger alert' do
        expect(deposit_bag_pathname.exist?).to be false
        allow(Honeybadger).to receive(:notify)
        expect { update_catalog_obj.perform(druid) }.not_to raise_error
        hb_notify_msg = "Deposit bag was missing. This is unusual; it's likely that the workflow step ran once before, and " \
                        "failed on the network call to preservation_catalog. Please confirm that #{druid} passes checksum " \
                        'validation in preservation_catalog, and that its preserved version matches the Cocina in dor-services-app.'
        expect(Honeybadger).to have_received(:notify).with(hb_notify_msg)
      end
    end

    context 'when object is new' do
      before do
        allow(deposit_bag_pathname).to receive(:rmtree)
      end

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
          update_catalog_obj.perform(bare_druid)
          expect(deposit_bag_pathname).to have_received(:rmtree)
        end
      end

      context 'when it removes the deposit bag and when HTTP fails twice with a retriable error' do
        before do
          2.times do
            stub_request(:post, 'http://localhost:3000/v1/catalog')
              .with(
                body: {
                  'checksums_validated' => true, 'druid' => 'bj102hs9687',
                  'incoming_size' => 2342, 'incoming_version' => 1,
                  'storage_location' => 'some/storage/location/from/endpoint/table'
                }
              )
              .to_timeout
          end

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

        it 'succeeds' do
          allow(LyberCore::Log).to receive(:warn).twice
          update_catalog_obj.perform(bare_druid)
          expect(deposit_bag_pathname).to have_received(:rmtree)
        end
      end

      context 'when HTTP fails thrice with a retriable error' do
        before do
          3.times do
            stub_request(:post, 'http://localhost:3000/v1/catalog')
              .with(
                body: {
                  'checksums_validated' => true, 'druid' => 'bj102hs9687',
                  'incoming_size' => 2342, 'incoming_version' => 1,
                  'storage_location' => 'some/storage/location/from/endpoint/table'
                }
              )
              .to_timeout
          end
        end

        it 'removes the deposit bag and fails' do
          expect { update_catalog_obj.perform(bare_druid) }.to raise_error(Preservation::Client::ConnectionFailedError)
          expect(deposit_bag_pathname).to have_received(:rmtree)
        end
      end

      context 'when HTTP fails with a non-retriable error' do
        before do
          stub_request(:post, 'http://localhost:3000/v1/catalog')
            .with(
              body: {
                'checksums_validated' => 'true', 'druid' => 'bj102hs9687',
                'incoming_size' => '2342', 'incoming_version' => '1',
                'storage_location' => 'some/storage/location/from/endpoint/table'
              }
            )
            .to_return(status: 500, body: '', headers: {})
        end

        it 'removes the deposit bag and fails' do
          expect { update_catalog_obj.perform(bare_druid) }.to raise_error(Preservation::Client::UnexpectedResponseError)
          expect(deposit_bag_pathname).to have_received(:rmtree)
        end
      end
    end

    context 'when object already exists' do
      let(:version) { 3 }

      context 'when preservation_catalog is not yet aware of the new version' do
        before do
          allow(deposit_bag_pathname).to receive(:rmtree)
          stub_request(:patch, 'http://localhost:3000/v1/catalog/bj102hs9687')
            .with(
              body: {
                'checksums_validated' => true, 'druid' => 'bj102hs9687',
                'incoming_size' => 2342, 'incoming_version' => 3,
                'storage_location' => 'some/storage/location/from/endpoint/table'
              }
            )
            .to_return(status: 200, body: '', headers: {})
        end

        it 'removes the deposit bag and PATCH to /v1/catalog/:druid' do
          update_catalog_obj.perform(bare_druid)
          expect(deposit_bag_pathname).to have_received(:rmtree)
        end
      end

      context 'when preservation_catalog is already aware of the new version' do
        before do
          allow(deposit_bag_pathname).to receive(:rmtree)
          allow(Honeybadger).to receive(:notify)
          stub_request(:patch, 'http://localhost:3000/v1/catalog/bj102hs9687')
            .with(
              body: {
                'checksums_validated' => true, 'druid' => 'bj102hs9687',
                'incoming_size' => 2342, 'incoming_version' => 3,
                'storage_location' => 'some/storage/location/from/endpoint/table'
              }
            )
            .to_return(status: 409, body: '', headers: {})
        end

        it 'removes the deposit bag, PATCH to /v1/catalog/:druid, and notifies due to the response' do
          update_catalog_obj.perform(bare_druid)
          expect(deposit_bag_pathname).to have_received(:rmtree)
          hb_notify_msg = "preservation_catalog has already ingested this object version.  This is unusual, but it's likely that a " \
                          'regularly scheduled preservation_catalog audit detected it after this workflow step was left in a failed state. ' \
                          'Please confirm that the preserved version matches the Cocina in dor-services-app.'
          expect(Honeybadger).to have_received(:notify).with(hb_notify_msg)
        end
      end
    end

    context 'when it attempts to stat the contents of the moab directory' do
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
        allow(deposit_bag_pathname).to receive(:rmtree).ordered
        allow(Find).to receive(:find).with(mock_moab_pathname).ordered.and_call_original

        # File.realpath will return a string representing "the real (absolute) pathname of pathname in the actual filesystem
        # not containing symlinks or useless dots" (see File class ruby docs).  this makes it easier to match the exact path
        # without worrying about absolute path differences between different dev laptops or laptops and CI (while also allowing
        # an exact match on path without just matching a substring).
        moab_file_and_dir_list.each { |path_str| allow(File).to receive(:stat).with(File.realpath(File.join(spec_dir, path_str))) }
        update_catalog_obj.perform(bare_druid)
        expect(deposit_bag_pathname).to have_received(:rmtree).ordered
        expect(Find).to have_received(:find).with(mock_moab_pathname).ordered
        moab_file_and_dir_list.each { |path_str| expect(File).to have_received(:stat).with(File.realpath(File.join(spec_dir, path_str))) }
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
