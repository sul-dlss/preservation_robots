# frozen_string_literal: true

RSpec.describe Robots::SdrRepo::PreservationIngest::UpdateMoab do
  let(:pres_update_moab) { described_class.new }
  let(:storage_root_and_trunk) { 'storage_root1/sdr2objects' }
  let(:full_druid) { 'druid:bj102hs9687' }
  let(:mock_pathname) { DruidTools::Druid.new(full_druid, storage_root_and_trunk).pathname }
  let(:mock_new_version) { instance_double(Moab::StorageObjectVersion) }
  let(:verification_result) { instance_double(Moab::VerificationResult) }
  let(:mock_storage_object) { instance_double(Moab::StorageObject, object_pathname: mock_pathname) }

  describe '#perform' do
    context 'with a single moab' do
      before do
        allow(Moab::StorageServices).to receive(:find_storage_object).and_return(mock_storage_object)
      end

      it 'calls #ingest_bag and verify_version_storage on Moab::StorageObjectVersion' do
        allow(mock_storage_object).to receive(:ingest_bag).and_return(mock_new_version)
        allow(verification_result).to receive(:verified).and_return(true)
        allow(mock_new_version).to receive(:verify_version_storage).and_return(verification_result)
        test_perform(pres_update_moab, full_druid)
        expect(mock_storage_object).to have_received(:ingest_bag)
        expect(mock_new_version).to have_received(:verify_version_storage)
      end

      it 'raises ItemError when new version does not pass verification' do
        full_druid_vers = "#{full_druid}-v0003"
        error_message = "Failed verification for #{full_druid_vers}"
        allow(mock_storage_object).to receive(:ingest_bag).and_return(mock_new_version)
        allow(verification_result).to receive_messages(verified: false, to_json: 'some_json', entity: full_druid_vers)
        allow(mock_new_version).to receive(:verify_version_storage).and_return(verification_result)
        expect { test_perform(pres_update_moab, full_druid) }.to raise_error(Robots::SdrRepo::PreservationIngest::ItemError, error_message)
        expect(mock_storage_object).to have_received(:ingest_bag)
        expect(mock_new_version).to have_received(:verify_version_storage)
      end
    end
  end
end
