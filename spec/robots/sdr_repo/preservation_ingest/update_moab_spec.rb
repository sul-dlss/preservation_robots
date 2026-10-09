# frozen_string_literal: true

RSpec.describe Robots::SdrRepo::PreservationIngest::UpdateMoab do
  let(:pres_update_moab) { described_class.new }
  let(:storage_root_and_trunk) { 'storage_root1/sdr2objects' }
  let(:full_druid) { 'druid:bj102hs9687' }
  let(:mock_pathname) { DruidTools::Druid.new(full_druid, storage_root_and_trunk).pathname }
  let(:mock_deposit_bag_pathname) { Pathname('storage_root1/deposit/bj102hs9687') }
  let(:mock_new_version) { instance_double(Moab::StorageObjectVersion) }
  let(:verification_result) { instance_double(Moab::VerificationResult) }
  let(:mock_storage_object) do
    instance_double(Moab::StorageObject, object_pathname: mock_pathname, deposit_bag_pathname: mock_deposit_bag_pathname)
  end
  let(:write_capability_waiter) { instance_double(Ceph::WriteCapabilityWaiter, wait: nil) }

  describe '#perform' do
    context 'with a single moab' do
      before do
        allow(Moab::StorageServices).to receive(:find_storage_object).and_return(mock_storage_object)
        allow(Ceph::WriteCapabilityWaiter).to receive(:new).and_return(write_capability_waiter)
      end

      it 'calls #ingest_bag and verify_version_storage on Moab::StorageObjectVersion' do
        allow(mock_storage_object).to receive(:ingest_bag).and_return(mock_new_version)
        allow(verification_result).to receive(:verified).and_return(true)
        allow(mock_new_version).to receive(:verify_version_storage).and_return(verification_result)
        test_perform(pres_update_moab, full_druid)
        expect(mock_storage_object).to have_received(:ingest_bag)
        expect(mock_new_version).to have_received(:verify_version_storage)
      end

      it 'waits for other hosts to release write capabilities on the deposit bag and the Moab' do
        allow(mock_storage_object).to receive(:ingest_bag).and_return(mock_new_version)
        allow(verification_result).to receive(:verified).and_return(true)
        allow(mock_new_version).to receive(:verify_version_storage).and_return(verification_result)
        test_perform(pres_update_moab, full_druid)
        expect(Ceph::WriteCapabilityWaiter).to have_received(:new)
          .with(pathnames: [mock_deposit_bag_pathname, mock_pathname], logger: anything)
        expect(write_capability_waiter).to have_received(:wait)
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

      it 'raises ItemError without ingesting when another host is still holding write capabilities' do
        allow(mock_storage_object).to receive(:ingest_bag)
        allow(write_capability_waiter).to receive(:wait)
          .and_raise(Ceph::WriteCapabilitiesHeldError, 'gave up after 120s waiting')
        expect { test_perform(pres_update_moab, full_druid) }
          .to raise_error(Robots::SdrRepo::PreservationIngest::ItemError,
                          "Write capabilities still held for #{full_druid}: gave up after 120s waiting")
        expect(mock_storage_object).not_to have_received(:ingest_bag)
      end
    end
  end
end
