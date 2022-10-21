# frozen_string_literal: true

require 'fileutils'

RSpec.describe Robots::SdrRepo::PreservationIngest::TransferObject do
  let(:bare_druid) { 'jc837rq9922' }
  let(:druid) { "druid:#{bare_druid}" }
  let(:vm_file_path) do
    File.join(Settings.transfer_object.from_dir, bare_druid, described_class::VERSION_METADATA_PATH_SUFFIX)
  end
  let(:deposit_dir_pathname) { Pathname(File.join(File.dirname(__FILE__), '..', 'fixtures', 'deposit', 'foo')) }
  let(:deposit_bag_pathname) { Pathname(File.join(deposit_dir_pathname, bare_druid)) }
  let(:xfer_obj) { described_class.new }

  before do
    # NOTE: Both of these lines are here to cover the two methods currently used
    #       to transfer bags. Once the SCP feature flag has been turned on for
    #       good, or removed, we should remove one of these lines.
    allow(Open3).to receive(:pipeline_r) # for transfer via tarpipe
    allow(Open3).to receive(:popen2e) # for transfer via scp
  end

  after do
    FileUtils.rm_rf(deposit_dir_pathname)
  end

  context 'when versionMetadata.xml file does not exist' do
    let(:cmd_regex) { Regexp.new(".*ssh #{Settings.transfer_object.from_host} test -e #{vm_file_path}.*") }

    before do
      allow(Robots::SdrRepo::PreservationIngest::Base).to receive(:execute_shell_command).and_return('no')
    end

    it 'raises ItemError if versionMetadata.xml file for druid does not exist' do
      expect { xfer_obj.perform(druid) }.to raise_error Robots::SdrRepo::PreservationIngest::ItemError,
                                                        "Error transferring bag (via userid@dor-services-app) for #{druid}: #{vm_file_path} not found"
      expect(Robots::SdrRepo::PreservationIngest::Base).to have_received(:execute_shell_command).with(a_string_matching(cmd_regex))
    end
  end

  describe 'creating a path for the deposit bag' do
    let(:mock_moab) { instance_double(Moab::StorageObject, deposit_bag_pathname: deposit_bag_pathname) }

    before do
      allow(xfer_obj).to receive(:verify_version_metadata)
      allow(Stanford::StorageServices).to receive(:find_storage_object).and_return(mock_moab)
    end

    it 'ensures the deposit_dir_pathname is created if it does not exist' do
      expect(deposit_dir_pathname).not_to exist
      xfer_obj.perform(druid)
      expect(deposit_dir_pathname).to exist
    end

    it 'removes previous bag if it exists' do
      FileUtils.mkdir_p(deposit_bag_pathname)
      FileUtils.touch("#{deposit_bag_pathname}bagit_file.txt")
      expect(deposit_bag_pathname).to exist
      xfer_obj.perform(druid)
      expect(deposit_bag_pathname).not_to exist
    end

    it 'raises an ItemError if previous bag is not removed' do
      FileUtils.mkdir_p(deposit_bag_pathname)
      FileUtils.touch("#{deposit_bag_pathname}bagit_file.txt")
      expect(deposit_bag_pathname).to exist
      allow(deposit_bag_pathname).to receive(:rmtree).and_raise(StandardError, 'rmtree failed')
      exp_msg = Regexp.escape("Error transferring bag (via userid@dor-services-app) for #{druid}: Failed preparation of deposit dir #{deposit_bag_pathname}")
      expect do
        xfer_obj.perform(druid)
      end.to raise_error(Robots::SdrRepo::PreservationIngest::ItemError, a_string_matching(exp_msg))
      expect(deposit_bag_pathname).to exist
    end
  end

  context 'when there is an error executing the transfer' do
    let(:mock_moab) { instance_double(Moab::StorageObject, deposit_bag_pathname: deposit_bag_pathname) }
    let(:exp_msg) { Regexp.escape("Error transferring bag (via userid@dor-services-app) for #{druid}: tarpipe failed") }

    before do
      allow(xfer_obj).to receive(:verify_version_metadata)
      allow(Stanford::StorageServices).to receive(:find_storage_object).and_return(mock_moab)
      allow(Settings.transfer_object).to receive(:via_scp).and_return(scp_flag_enabled)
    end

    context 'when transferring via tarpipe' do
      let(:scp_flag_enabled) { false }

      before do
        allow(Open3).to receive(:pipeline_r).and_raise(StandardError, 'tarpipe failed')
      end

      it 'raises ItemError if there is a StandardError while executing the tarpipe command' do
        expect do
          xfer_obj.perform(druid)
        end.to raise_error(Robots::SdrRepo::PreservationIngest::ItemError, a_string_matching(exp_msg))
      end
    end

    context 'when transferring via scp' do
      let(:scp_flag_enabled) { true }

      before do
        allow(Open3).to receive(:popen2e).and_raise(StandardError, 'tarpipe failed')
      end

      it 'raises ItemError if there is a StandardError while executing the tarpipe command' do
        expect do
          xfer_obj.perform(druid)
        end.to raise_error(Robots::SdrRepo::PreservationIngest::ItemError, a_string_matching(exp_msg))
      end
    end
  end

  context 'when no errors are raised' do
    let(:mock_moab) { instance_double(Moab::StorageObject, deposit_bag_pathname: deposit_bag_pathname) }
    let(:cmd_regex) { Regexp.new("if ssh #{Settings.transfer_object.from_host} test -e #{vm_file_path}.*") }

    before do
      allow(Robots::SdrRepo::PreservationIngest::Base).to receive(:execute_shell_command).and_return('yes')
      allow(Stanford::StorageServices).to receive(:find_storage_object).and_return(mock_moab)
      allow(Settings.transfer_object).to receive(:via_scp).and_return(scp_flag_enabled)
    end

    context 'when transferring via tarpipe' do
      let(:scp_flag_enabled) { false }

      it 'transfers the object' do
        expect(deposit_bag_pathname).not_to exist
        xfer_obj.perform(druid)
        expect(Open3).to have_received(:pipeline_r).with(
          'ssh userid@dor-services-app "tar -C /dor/export/ --dereference -cf - jc837rq9922 "', /^tar -C/
        )
        expect(Robots::SdrRepo::PreservationIngest::Base).to have_received(:execute_shell_command).with(a_string_matching(cmd_regex))
        expect(Stanford::StorageServices).to have_received(:find_storage_object)
      end
    end

    context 'when transferring via scp' do
      let(:scp_flag_enabled) { true }

      it 'transfers the object' do
        expect(deposit_bag_pathname).not_to exist
        xfer_obj.perform(druid)
        expect(Open3).to have_received(:popen2e).with(
          %r{scp -pqr userid@dor-services-app:/dor/export/jc837rq9922 .+/spec/preservation_ingest/../fixtures/deposit/foo}
        )
        expect(Robots::SdrRepo::PreservationIngest::Base).to have_received(:execute_shell_command).with(a_string_matching(cmd_regex))
        expect(Stanford::StorageServices).to have_received(:find_storage_object)
      end
    end
  end
end
