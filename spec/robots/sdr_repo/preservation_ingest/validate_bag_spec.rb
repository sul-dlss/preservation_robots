# frozen_string_literal: true

RSpec.describe Robots::SdrRepo::PreservationIngest::ValidateBag do
  subject(:validate_bag_obj) { described_class.new }

  let(:deposit_dir_pathname) { Pathname(File.join(File.dirname(__FILE__), '..', '..', '..', 'fixtures', 'deposit')) }
  let(:deposit_bag_pathname) { Pathname(File.join(deposit_dir_pathname, bare_druid)) }
  let(:moab_object_pathname) { Pathname(File.join(deposit_dir_pathname, '..', 'sdr2objects', bare_druid)) }
  let(:druid) { "druid:#{bare_druid}" }
  let(:mock_moab) do
    instance_double(Moab::StorageObject,
                    deposit_bag_pathname: deposit_bag_pathname,
                    object_pathname: moab_object_pathname,
                    current_version_id: 5)
  end
  let(:write_capability_waiter) { instance_double(Ceph::WriteCapabilityWaiter, wait: nil) }

  before do
    allow(Stanford::StorageServices).to receive(:find_storage_object).and_return(mock_moab)
    allow(Ceph::WriteCapabilityWaiter).to receive(:new).and_return(write_capability_waiter)
  end

  context 'when no validation errors' do
    let(:bare_druid) { 'cr123dt0367' }

    it 'no error is raised' do
      expect { test_perform(validate_bag_obj, druid) }.not_to raise_error
    end

    it 'waits for other hosts to release write capabilities on the deposit bag and the Moab' do
      test_perform(validate_bag_obj, druid)
      expect(Ceph::WriteCapabilityWaiter).to have_received(:new)
        .with(pathnames: [deposit_bag_pathname, moab_object_pathname], logger: anything)
      expect(write_capability_waiter).to have_received(:wait)
    end
  end

  context 'when validation errors' do
    let(:bare_druid) { 'oo000oo0000' }

    it 'raises ItemError' do
      missing_file_regex_str = Regexp.escape('/oo000oo0000/data/metadata/versionMetadata.xml')
      exp_msg = "Bag validation failure.*required_file_not_found.*#{missing_file_regex_str} not found"
      expect { test_perform(validate_bag_obj, druid) }.to raise_error(Robots::SdrRepo::PreservationIngest::ItemError, a_string_matching(exp_msg))
    end
  end

  context 'when another host is still holding write capabilities' do
    let(:bare_druid) { 'cr123dt0367' }

    before do
      allow(write_capability_waiter).to receive(:wait)
        .and_raise(Ceph::WriteCapabilitiesHeldError, 'gave up after 120s waiting')
    end

    it 'raises ItemError without validating the bag' do
      expect { test_perform(validate_bag_obj, druid) }
        .to raise_error(Robots::SdrRepo::PreservationIngest::ItemError,
                        "Write capabilities still held for #{druid}: gave up after 120s waiting")
    end
  end
end
