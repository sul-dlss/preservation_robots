# frozen_string_literal: true

require 'fileutils'

RSpec.describe Robots::SdrRepo::PreservationIngest::WriteNewMoabVersion do
  let(:write_new_moab_version) { described_class.new }

  describe 'the order of the work performed' do
    let(:druid) { 'druid:bc123df4567' }

    before do
      allow(write_new_moab_version).to receive(:verify_prepare_and_transfer)
      allow(write_new_moab_version).to receive(:validate_bag)
      allow(write_new_moab_version).to receive(:update_moab)
    end

    it 'transfers the deposit bag, then validates it, then ingests it into the Moab' do
      test_perform(write_new_moab_version, druid)
      expect(write_new_moab_version).to have_received(:verify_prepare_and_transfer).ordered
      expect(write_new_moab_version).to have_received(:validate_bag).ordered
      expect(write_new_moab_version).to have_received(:update_moab).ordered
    end
  end

  describe 'transferring the deposit bag' do
    let(:bare_druid) { 'jc837rq9922' }
    let(:druid) { "druid:#{bare_druid}" }
    let(:version_metadata_file_path) do
      from_dir = File.join(Settings.transfer_object.from_dir, bare_druid)
      File.join(from_dir, described_class::VERSION_METADATA_PATH_SUFFIX)
    end
    let(:deposit_dir_pathname) { Pathname(File.join(File.dirname(__FILE__), '..', 'fixtures', 'deposit', 'foo')) }
    let(:deposit_bag_pathname) { Pathname(File.join(deposit_dir_pathname, bare_druid)) }

    before do
      allow(write_new_moab_version).to receive(:validate_bag)
      allow(write_new_moab_version).to receive(:update_moab)
    end

    after do
      deposit_dir_pathname.rmtree if deposit_dir_pathname.exist?
    end

    context 'when versionMetadata.xml file temporarily does not exist' do
      before do
        allow(write_new_moab_version).to receive(:sleep)
        call_count = 0
        allow(write_new_moab_version).to receive(:verify_version_metadata) do
          call_count += 1
          raise StandardError, 'Simulated transient error' if call_count == 1
        end
        allow(write_new_moab_version).to receive(:prepare_deposit_dir)
        allow(write_new_moab_version).to receive(:transfer_bag)
      end

      it 'retries and then transfers the bag' do
        test_perform(write_new_moab_version, druid)
        expect(write_new_moab_version).to have_received(:sleep).once
        expect(write_new_moab_version).to have_received(:verify_version_metadata).exactly(2).times
        expect(write_new_moab_version).to have_received(:prepare_deposit_dir).once
        expect(write_new_moab_version).to have_received(:transfer_bag).once
      end
    end

    context 'when versionMetadata.xml file does not exist' do
      before do
        allow(write_new_moab_version).to receive(:sleep)
      end

      it 'retries and raises ItemError if versionMetadata.xml file for druid does not exist' do
        expect { test_perform(write_new_moab_version, druid) }.to raise_error(
          Robots::SdrRepo::PreservationIngest::ItemError,
          "Error transferring bag (via #{Settings.transfer_object.from_dir}) for #{druid}: #{version_metadata_file_path} not found"
        )
        expect(write_new_moab_version).to have_received(:sleep).exactly(5).times
      end
    end

    describe 'creating a path for the deposit bag' do
      let(:expected_message) do
        Regexp.escape("Error transferring bag (via #{Settings.transfer_object.from_dir}) for #{druid}: " \
                      "Failed preparation of deposit dir #{deposit_bag_pathname}")
      end
      let(:mock_moab) { instance_double(Moab::StorageObject, deposit_bag_pathname: deposit_bag_pathname) }

      before do
        allow(write_new_moab_version).to receive(:verify_version_metadata)
        allow(write_new_moab_version).to receive(:transfer_bag)
        allow(Stanford::StorageServices).to receive(:find_storage_object).and_return(mock_moab)
      end

      it 'ensures the deposit_dir_pathname is created if it does not exist' do
        expect(deposit_dir_pathname.exist?).to be false
        test_perform(write_new_moab_version, druid)
        expect(deposit_dir_pathname.exist?).to be true
      end

      it 'removes previous bag if it exists' do
        FileUtils.mkdir_p(deposit_bag_pathname)
        FileUtils.touch("#{deposit_bag_pathname}bagit_file.txt")
        expect(deposit_bag_pathname.exist?).to be true
        test_perform(write_new_moab_version, druid)
        expect(deposit_bag_pathname.exist?).to be false
      end

      it 'raises an ItemError if previous bag is not removed' do
        FileUtils.mkdir_p(deposit_bag_pathname)
        FileUtils.touch("#{deposit_bag_pathname}bagit_file.txt")
        expect(deposit_bag_pathname).to exist
        allow(deposit_bag_pathname).to receive(:rmtree).and_raise(StandardError, 'rmtree failed')
        expect do
          test_perform(write_new_moab_version, druid)
        end.to raise_error(Robots::SdrRepo::PreservationIngest::ItemError, a_string_matching(expected_message))
        expect(deposit_bag_pathname.exist?).to be true
      end
    end

    context 'when there is an error executing the transfer' do
      let(:mock_moab) { instance_double(Moab::StorageObject, deposit_bag_pathname: deposit_bag_pathname) }
      let(:expected_message) do
        Regexp.escape("Error transferring bag (via #{Settings.transfer_object.from_dir}) for #{druid}: permission denied")
      end

      before do
        allow(write_new_moab_version).to receive(:verify_version_metadata)
        allow(Stanford::StorageServices).to receive(:find_storage_object).and_return(mock_moab)
        allow(Open3).to receive(:popen2e).and_raise(StandardError, 'permission denied')
        allow(write_new_moab_version).to receive(:sleep)
      end

      it 'raises ItemError if there is a StandardError while executing the transfer command' do
        expect do
          test_perform(write_new_moab_version, druid)
        end.to raise_error(Robots::SdrRepo::PreservationIngest::ItemError, a_string_matching(expected_message))
        expect(write_new_moab_version).to have_received(:sleep).exactly(5).times
      end
    end

    context 'when there is a transient error executing the transfer' do
      let(:mock_moab) { instance_double(Moab::StorageObject, deposit_bag_pathname: deposit_bag_pathname) }

      before do
        allow(write_new_moab_version).to receive(:verify_version_metadata)
        allow(Stanford::StorageServices).to receive(:find_storage_object).and_return(mock_moab)
        allow(write_new_moab_version).to receive(:sleep)
        call_count = 0
        allow(Open3).to receive(:popen2e) do
          call_count += 1
          raise StandardError, 'Simulated transient error' if call_count == 1
        end
      end

      it 'retries and then transfers the bag' do
        test_perform(write_new_moab_version, druid)
        expect(write_new_moab_version).to have_received(:sleep).exactly(1).times
        expect(Open3).to have_received(:popen2e).exactly(2).times
      end
    end

    context 'when no errors are raised' do
      let(:mock_moab) { instance_double(Moab::StorageObject, deposit_bag_pathname: deposit_bag_pathname) }

      before do
        allow(write_new_moab_version).to receive(:verify_version_metadata)
        allow(Stanford::StorageServices).to receive(:find_storage_object).and_return(mock_moab)
        allow(Open3).to receive(:popen2e)
      end

      it 'transfers the object' do
        expect(deposit_bag_pathname.exist?).to be false
        test_perform(write_new_moab_version, druid)
        expect(Open3).to have_received(:popen2e).with(
          %r{cp -rL /dor/export/jc837rq9922 .+/spec/robots/sdr_repo/preservation_ingest/../fixtures/deposit/foo}
        )
        expect(Stanford::StorageServices).to have_received(:find_storage_object)
      end
    end
  end

  describe 'validating the deposit bag' do
    let(:deposit_dir_pathname) { Pathname(File.join(File.dirname(__FILE__), '..', '..', '..', 'fixtures', 'deposit')) }
    let(:deposit_bag_pathname) { Pathname(File.join(deposit_dir_pathname, bare_druid)) }
    let(:druid) { "druid:#{bare_druid}" }
    let(:mock_moab) do
      instance_double(Moab::StorageObject,
                      deposit_bag_pathname: deposit_bag_pathname,
                      current_version_id: 5)
    end

    before do
      allow(write_new_moab_version).to receive(:verify_prepare_and_transfer)
      allow(write_new_moab_version).to receive(:update_moab)
      allow(Stanford::StorageServices).to receive(:find_storage_object).and_return(mock_moab)
    end

    context 'when no validation errors' do
      let(:bare_druid) { 'cr123dt0367' }

      it 'no error is raised' do
        expect { test_perform(write_new_moab_version, druid) }.not_to raise_error
      end
    end

    context 'when validation errors' do
      let(:bare_druid) { 'oo000oo0000' }

      it 'raises ItemError' do
        missing_file_regex_str = Regexp.escape('/oo000oo0000/data/metadata/versionMetadata.xml')
        exp_msg = "Bag validation failure.*required_file_not_found.*#{missing_file_regex_str} not found"
        expect { test_perform(write_new_moab_version, druid) }.to raise_error(Robots::SdrRepo::PreservationIngest::ItemError, a_string_matching(exp_msg))
      end
    end

    context 'when validation fails' do
      let(:bare_druid) { 'oo000oo0000' }

      it 'does not ingest the bag into the Moab' do
        expect { test_perform(write_new_moab_version, druid) }.to raise_error(Robots::SdrRepo::PreservationIngest::ItemError)
        expect(write_new_moab_version).not_to have_received(:update_moab)
      end
    end
  end

  describe 'ingesting the deposit bag into the Moab' do
    let(:druid) { 'druid:bj102hs9687' }
    let(:mock_new_version) { instance_double(Moab::StorageObjectVersion) }
    let(:verification_result) { instance_double(Moab::VerificationResult) }
    let(:mock_storage_object) { instance_double(Moab::StorageObject) }

    before do
      allow(write_new_moab_version).to receive(:verify_prepare_and_transfer)
      allow(write_new_moab_version).to receive(:validate_bag)
      allow(Stanford::StorageServices).to receive(:find_storage_object).and_return(mock_storage_object)
      allow(mock_storage_object).to receive(:ingest_bag).and_return(mock_new_version)
      allow(mock_new_version).to receive(:verify_version_storage).and_return(verification_result)
    end

    context 'when the new version passes verification' do
      before do
        allow(verification_result).to receive(:verified).and_return(true)
      end

      it 'calls #ingest_bag and verify_version_storage on Moab::StorageObjectVersion' do
        test_perform(write_new_moab_version, druid)
        expect(mock_storage_object).to have_received(:ingest_bag).with(use_links: false)
        expect(mock_new_version).to have_received(:verify_version_storage)
      end
    end

    context 'when the new version does not pass verification' do
      let(:full_druid_vers) { "#{druid}-v0003" }

      before do
        allow(verification_result).to receive_messages(verified: false, to_json: 'some_json', entity: full_druid_vers)
      end

      it 'raises ItemError' do
        error_message = "Failed verification for #{full_druid_vers}"
        expect { test_perform(write_new_moab_version, druid) }.to raise_error(Robots::SdrRepo::PreservationIngest::ItemError, error_message)
        expect(mock_storage_object).to have_received(:ingest_bag)
        expect(mock_new_version).to have_received(:verify_version_storage)
      end
    end
  end
end
