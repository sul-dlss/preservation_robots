# frozen_string_literal: true

RSpec.describe Robots::SdrRepo::PreservationIngest::CompleteIngest do
  let(:this_robot) { described_class.new }
  let(:druid) { 'druid:jc837rq9922' }

  let(:object_client) { instance_double(Dor::Services::Client::Object, workflow: workflow) }
  let(:workflow) { instance_double(Dor::Services::Client::ObjectWorkflow, process: process_client) }
  let(:process_client) { instance_double(Dor::Services::Client::Process, update: true) }

  before do
    allow(this_robot).to receive(:object_client).and_return(object_client)
  end

  describe '#perform' do
    context 'when it fails to update the accessionWF sdr-ingest-received step' do
      before do
        allow(process_client).to receive(:update).and_raise(Dor::Services::Client::Error, 'foo')
      end

      it 'raises ItemError' do
        exp_msg = "#{Regexp.escape("Error completing ingest for #{druid}: failed to update accessionWF:sdr-ingest-received to completed: ")}.*foo"
        expect { test_perform(this_robot, druid) }.to raise_error(Robots::SdrRepo::PreservationIngest::ItemError, a_string_matching(exp_msg))
      end
    end

    it 'updates the accessionWF when no errors are raised' do
      test_perform(this_robot, druid)
      expect(object_client).to have_received(:workflow).with('accessionWF')
      expect(process_client).to have_received(:update)
        .with(status: 'completed', note: String)
    end
  end
end
