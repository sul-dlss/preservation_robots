# frozen_string_literal: true

RSpec.describe Robots::SdrRepo::PreservationIngest::CompleteIngest do
  let(:this_robot) { described_class.new }
  let(:druid) { 'druid:jc837rq9922' }

  describe '#perform' do
    context 'when it fails to update the accessionWF sdr-ingest-received step' do
      before do
        allow(this_robot.workflow_service).to receive(:update_status).and_raise(Dor::WorkflowException.new('foo'))
      end

      it 'raises ItemError' do
        exp_msg = "#{Regexp.escape("Error completing ingest for #{druid}: failed to update accessionWF:sdr-ingest-received to completed: ")}.*foo"
        expect { this_robot.perform(druid) }.to raise_error(Robots::SdrRepo::PreservationIngest::ItemError, a_string_matching(exp_msg))
      end
    end

    it 'updates the accessionWF when no errors are raised' do
      allow(this_robot.workflow_service).to receive(:update_status)
        .with(druid: druid,
              workflow: 'accessionWF',
              process: 'sdr-ingest-received',
              status: 'completed',
              elapsed: 1,
              note: String)
      expect { this_robot.perform(druid) }.not_to raise_error
      expect(this_robot.workflow_service).to have_received(:update_status)
        .with(druid: druid,
              workflow: 'accessionWF',
              process: 'sdr-ingest-received',
              status: 'completed',
              elapsed: 1,
              note: String)
    end
  end
end
