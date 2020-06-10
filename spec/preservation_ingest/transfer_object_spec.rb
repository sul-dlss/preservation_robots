describe Robots::SdrRepo::PreservationIngest::TransferObject do
  let(:bare_druid) { 'jc837rq9922' }
  let(:druid) { "druid:#{bare_druid}" }
  let(:vm_file_path) do
    from_dir = File.join(Settings.transfer_object.from_dir, bare_druid)
    File.join(from_dir, described_class::VERSION_METADATA_PATH_SUFFIX)
  end
  let(:deposit_dir_pathname) { Pathname(File.join(File.dirname(__FILE__), '..', 'fixtures', 'deposit', 'foo')) }
  let(:deposit_bag_pathname) { Pathname(File.join(deposit_dir_pathname, bare_druid)) }
  let(:xfer_obj) { described_class.new }

  after do
    deposit_dir_pathname.rmtree if deposit_dir_pathname.exist?
  end

  it 'raises ItemError if versionMetadata.xml file for druid does not exist' do
    allow(xfer_obj).to receive(:verify_accesssion_wf_step_completed)
    cmd_regex = Regexp.new(".*ssh #{Settings.transfer_object.from_host} test -e #{vm_file_path}.*")
    expect(Robots::SdrRepo::PreservationIngest::Base).to receive(:execute_shell_command).with(a_string_matching(cmd_regex)).and_return('no')
    exp_msg = "Error transferring bag (via userid@dor-services-app) for #{druid}: #{vm_file_path} not found"
    expect { xfer_obj.perform(druid) }.to raise_error(Robots::SdrRepo::PreservationIngest::ItemError, exp_msg)
  end

  describe 'deposit bag path' do
    require 'fileutils'

    before do
      allow(xfer_obj).to receive(:verify_accesssion_wf_step_completed)
      allow(xfer_obj).to receive(:verify_version_metadata)
      mock_moab = instance_double(Moab::StorageObject)
      allow(mock_moab).to receive(:deposit_bag_pathname).and_return(deposit_bag_pathname)
      allow(Stanford::StorageServices).to receive(:find_storage_object).and_return(mock_moab)
      xfer_obj.instance_variable_set(:@druid, druid)
      tarpipe_cmd = xfer_obj.send(:tarpipe_command, deposit_dir_pathname)
      allow(Robots::SdrRepo::PreservationIngest::Base).to receive(:execute_shell_command).with(tarpipe_cmd)
    end

    it 'ensures the deposit_dir_pathname is created if it does not exist' do
      expect(deposit_dir_pathname.exist?).to be false
      xfer_obj.perform(druid)
      expect(deposit_dir_pathname.exist?).to be true
    end

    it 'removes previous bag if it exists' do
      FileUtils.mkdir_p(deposit_bag_pathname)
      FileUtils.touch(deposit_bag_pathname + 'bagit_file.txt')
      expect(deposit_bag_pathname.exist?).to be true
      xfer_obj.perform(druid)
      expect(deposit_bag_pathname.exist?).to be false
    end

    it 'raises an ItemError if previous bag is not removed' do
      FileUtils.mkdir_p(deposit_bag_pathname)
      FileUtils.touch(deposit_bag_pathname + 'bagit_file.txt')
      expect(deposit_bag_pathname.exist?).to be true
      expect(deposit_bag_pathname).to receive(:rmtree).and_raise(StandardError, 'rmtree failed')
      exp_msg = Regexp.escape("Error transferring bag (via userid@dor-services-app) for #{druid}: Failed preparation of deposit dir #{deposit_bag_pathname}")
      expect { xfer_obj.perform(druid) }.to raise_error(Robots::SdrRepo::PreservationIngest::ItemError, a_string_matching(exp_msg))
      expect(deposit_bag_pathname.exist?).to be true
    end
  end

  it 'raises ItemError if there is a StandardError while executing the tarpipe command' do
    allow(xfer_obj).to receive(:verify_accesssion_wf_step_completed)
    allow(xfer_obj).to receive(:verify_version_metadata)
    mock_moab = instance_double(Moab::StorageObject)
    allow(mock_moab).to receive(:deposit_bag_pathname).and_return(deposit_bag_pathname)
    allow(Stanford::StorageServices).to receive(:find_storage_object).and_return(mock_moab)

    xfer_obj.instance_variable_set(:@druid, druid)
    tarpipe_cmd = xfer_obj.send(:tarpipe_command, deposit_dir_pathname)
    allow(Robots::SdrRepo::PreservationIngest::Base).to receive(:execute_shell_command)
      .with(tarpipe_cmd).and_raise(StandardError, 'tarpipe failed')
    exp_msg = Regexp.escape("Error transferring bag (via userid@dor-services-app) for #{druid}: tarpipe failed")
    expect { xfer_obj.perform(druid) }.to raise_error(Robots::SdrRepo::PreservationIngest::ItemError, a_string_matching(exp_msg))
  end

  it 'executes the tarpipe command to transfer the object when no errors are raised' do
    expect(deposit_bag_pathname.exist?).to be false

    cmd_regex = Regexp.new("if ssh #{Settings.transfer_object.from_host} test -e #{vm_file_path}.*")
    expect(Robots::SdrRepo::PreservationIngest::Base).to receive(:execute_shell_command).with(a_string_matching(cmd_regex)).and_return('yes')

    mock_moab = instance_double(Moab::StorageObject)
    expect(mock_moab).to receive(:deposit_bag_pathname).and_return(deposit_bag_pathname)
    expect(Stanford::StorageServices).to receive(:find_storage_object).and_return(mock_moab)

    xfer_obj.instance_variable_set(:@druid, druid)
    tarpipe_cmd = xfer_obj.send(:tarpipe_command, deposit_dir_pathname)
    expect(Robots::SdrRepo::PreservationIngest::Base).to receive(:execute_shell_command).with(tarpipe_cmd)

    xfer_obj.perform(druid)
  end
end
