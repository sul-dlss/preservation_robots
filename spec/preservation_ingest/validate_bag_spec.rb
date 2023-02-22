# frozen_string_literal: true

RSpec.describe Robots::SdrRepo::PreservationIngest::ValidateBag do
  subject(:validate_bag_obj) { described_class.new }

  let(:deposit_dir_pathname) { Pathname(File.join(File.dirname(__FILE__), '..', 'fixtures', 'deposit')) }
  let(:deposit_bag_pathname) { Pathname(File.join(deposit_dir_pathname, bare_druid)) }
  let(:druid) { "druid:#{bare_druid}" }
  let(:mock_moab) do
    instance_double(Moab::StorageObject,
                    deposit_bag_pathname: deposit_bag_pathname,
                    current_version_id: 5)
  end

  before do
    allow(Stanford::StorageServices).to receive(:find_storage_object).and_return(mock_moab)
  end

  context 'when no validation errors' do
    let(:bare_druid) { 'cr123dt0367' }

    it 'no error is raised' do
      expect { test_perform(validate_bag_obj, druid) }.not_to raise_error
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
end
