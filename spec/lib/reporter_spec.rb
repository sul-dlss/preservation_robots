# frozen_string_literal: true

require 'reporter'
describe Reporter do
  let(:base_path) { "#{Dir.pwd}/spec/fixtures" }

  describe '.default_log_files' do
    it 'returns a filtered array of log files' do
      allow(Dir).to receive(:pwd).and_return(base_path)
      expect(described_class.default_log_files).to eq ["#{base_path}/log/sdr_preservationIngestWF_transfer-object.log",
                                                       "#{base_path}/log/sdr_preservationIngestWF_validate-bag.log"]
      expect(described_class.default_log_files).not_to include "#{base_path}/log/sdr_preservationIngestWF_validate-bag.log.1"
    end
  end
end
