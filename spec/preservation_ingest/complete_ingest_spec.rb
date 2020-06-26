describe Robots::SdrRepo::PreservationIngest::CompleteIngest do
  let(:bare_druid) { 'jc837rq9922' }
  let(:druid) { "druid:#{bare_druid}" }
  let(:deposit_dir_pathname) { Pathname(File.join(File.dirname(__FILE__), '..', 'fixtures', 'deposit', 'complete-ingest')) }
  let(:deposit_bag_pathname) { Pathname(File.join(deposit_dir_pathname, bare_druid)) }
  let(:mock_so) { instance_double(Moab::StorageObject, deposit_bag_pathname: deposit_bag_pathname) }
  let(:mock_sos) { [mock_so] }
  let(:this_robot) { described_class.new }

  describe '#perform' do
    before do
      allow(deposit_bag_pathname).to receive(:rmtree)
      allow(Moab::StorageServices).to receive(:search_storage_objects).and_return(mock_sos)
      allow(mock_sos).to receive(:filter!).and_return(mock_so)
      FileUtils.mkdir_p(deposit_bag_pathname)
      FileUtils.touch(deposit_bag_pathname + 'bagit_file.txt')
    end

    after do
      deposit_dir_pathname.rmtree if deposit_dir_pathname.exist?
    end

    it 'raises ItemError if it fails to remove the deposit bag' do
      expect(deposit_bag_pathname.exist?).to be true
      expect(deposit_bag_pathname).to receive(:rmtree).and_raise(StandardError, 'rmtree failed')
      exp_msg = Regexp.escape("Error completing ingest for #{druid}: failed to remove deposit bag (#{deposit_bag_pathname}): rmtree failed")
      expect { this_robot.perform(druid) }.to raise_error(Robots::SdrRepo::PreservationIngest::ItemError, a_string_matching(exp_msg))
      expect(deposit_bag_pathname.exist?).to be true
    end

    context 'if it fails to update the accessionWF sdr-ingest-received step' do
      before do
        allow(this_robot.workflow_service).to receive(:update_status).and_raise(Dor::WorkflowException.new('foo'))
      end

      it 'raises ItemError' do
        exp_msg = Regexp.escape("Error completing ingest for #{druid}: failed to update accessionWF:sdr-ingest-received to completed: ") + '.*foo'
        expect { this_robot.perform(druid) }.to raise_error(Robots::SdrRepo::PreservationIngest::ItemError, a_string_matching(exp_msg))
      end
    end

    it 'removes the deposit bag and updates the accessionWF when no errors are raised' do
      expect(deposit_bag_pathname).to receive(:rmtree)
      expect(this_robot.workflow_service).to receive(:update_status)
        .with(druid: druid,
              workflow: 'accessionWF',
              process: 'sdr-ingest-received',
              status: 'completed',
              elapsed: 1,
              note: String)
      expect { this_robot.perform(druid) }.not_to raise_error
    end
  end
end
