# frozen_string_literal: true

RSpec.describe Robots::SdrRepo::PreservationIngest::UpdateMoab do
  let(:pres_update_moab) { described_class.new }
  let(:storage_root_and_trunk) { 'storage_root1/sdr2objects' }
  let(:full_druid) { 'druid:bj102hs9687' }
  let(:mock_pathname) { DruidTools::Druid.new(full_druid, storage_root_and_trunk).pathname }
  let(:mock_new_version) { instance_double(Moab::StorageObjectVersion) }
  let(:verification_result) { instance_double(Moab::VerificationResult) }
  let(:mock_storage_object) { instance_double(Moab::StorageObject, object_pathname: mock_pathname) }
  let(:mock_storage_objects) { [mock_storage_object] }

  describe '#perform' do
    before do
      allow(Moab::StorageServices).to receive(:search_storage_objects).and_return(mock_storage_objects)
    end

    context 'with a single moab' do
      before do
        allow(Moab::StorageServices).to receive(:find_storage_object).and_return(mock_storage_object)
      end

      it 'calls #ingest_bag and verify_version_storage on Moab::StorageObjectVersion' do
        allow(LyberCore::Log).to receive(:debug).with('update-moab druid:bj102hs9687 starting')
        expect(mock_storage_object).to receive(:ingest_bag).and_return(mock_new_version)
        allow(verification_result).to receive(:verified).and_return(true)
        expect(mock_new_version).to receive(:verify_version_storage).and_return(verification_result)
        pres_update_moab.perform(full_druid)
      end

      it 'raises ItemError when new version does not pass verification' do
        full_druid_vers = "#{full_druid}-v0003"
        error_message = "Failed verification for #{full_druid_vers}"
        expect(mock_storage_object).to receive(:ingest_bag).and_return(mock_new_version)
        allow(verification_result).to receive(:verified).and_return(false)
        expect(mock_new_version).to receive(:verify_version_storage).and_return(verification_result)
        allow(verification_result).to receive(:to_json).and_return('some_json')
        allow(verification_result).to receive(:entity).and_return(full_druid_vers)
        expect(LyberCore::Log).to receive(:info).with('some_json')
        expect { pres_update_moab.perform(full_druid) }.to raise_error(Robots::SdrRepo::PreservationIngest::ItemError, error_message)
      end
    end

    context 'with multiple moabs' do
      let(:storage_root_and_trunk_2) { 'storage_root2/sdr2objects' }
      let(:mock_pathname_2) { DruidTools::Druid.new(full_druid, storage_root_and_trunk_2).pathname }
      let(:mock_storage_object_2) { instance_double(Moab::StorageObject, object_pathname: mock_pathname_2) }
      let(:mock_storage_objects) { [mock_storage_object, mock_storage_object_2] }

      before do
        allow(Preservation::Client.objects).to receive(:primary_moab_location).and_return('storage_root2/sdr2objects')
      end

      it 'calls #ingest_bag and verify_version_storage on Moab::StorageObjectVersion' do
        allow(LyberCore::Log).to receive(:debug).with('update-moab druid:bj102hs9687 starting')
        expect(mock_storage_object_2).to receive(:ingest_bag).and_return(mock_new_version)
        allow(verification_result).to receive(:verified).and_return(true)
        expect(mock_new_version).to receive(:verify_version_storage).and_return(verification_result)
        pres_update_moab.perform(full_druid)
      end
    end
  end
end
