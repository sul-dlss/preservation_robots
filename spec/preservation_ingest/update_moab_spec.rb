describe Robots::SdrRepo::PreservationIngest::UpdateMoab do
  let(:pres_update_moab) { described_class.new }
  let(:full_druid) { 'druid:bj102hs9687' }
  let(:mock_path) { instance_double(Pathname) }
  let(:mock_so) { instance_double(Moab::StorageObject, object_pathname: mock_path) }
  let(:mock_new_version) { instance_double(Moab::StorageObjectVersion) }
  let(:verification_result) { instance_double(Moab::VerificationResult) }

  describe '#perform' do
    before do
      allow(Moab::StorageServices).to receive(:search_storage_objects).and_return(mock_so)
    end

    it 'calls #ingest_bag and verify_version_storage on Moab::StorageObjectVersion' do
      allow(LyberCore::Log).to receive(:debug).with('update-moab druid:bj102hs9687 starting')
      expect(mock_so).to receive(:ingest_bag).and_return(mock_new_version)
      allow(verification_result).to receive(:verified).and_return(true)
      expect(mock_new_version).to receive(:verify_version_storage).and_return(verification_result)
      pres_update_moab.perform(full_druid)
    end

    it 'raises ItemError when new version does not pass verification' do
      full_druid_vers = "#{full_druid}-v0003"
      error_message = "Failed verification for #{full_druid_vers}"
      expect(mock_so).to receive(:ingest_bag).and_return(mock_new_version)
      allow(verification_result).to receive(:verified).and_return(false)
      expect(mock_new_version).to receive(:verify_version_storage).and_return(verification_result)
      allow(verification_result).to receive(:to_json).and_return('some_json')
      allow(verification_result).to receive(:entity).and_return(full_druid_vers)
      expect(LyberCore::Log).to receive(:info).with('some_json')
      expect { pres_update_moab.perform(full_druid) }.to raise_error(Robots::SdrRepo::PreservationIngest::ItemError, error_message)
    end
  end
end
