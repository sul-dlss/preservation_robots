# frozen_string_literal: true

require 'activity_reporter'
describe ActivityReporter do
  let(:date) { '2017-04-27' }
  let(:activity_reporter) { described_class.new }
  let(:base_path) { "#{Dir.pwd}/spec/fixtures" }
  let(:error_path) { "#{base_path}/log/sdr_preservationIngestWF_transfer-object.log" }
  let(:happy_path) { "#{base_path}/log/sdr_preservationIngestWF_validate-bag.log" }
  let(:dbl_date) { instance_double(Time, to_date: date) }
  let(:output) { activity_reporter.output }

  before do
    allow($stdout).to receive(:puts)
  end

  describe '#output' do
    context 'when file does not exist' do
      before do
        allow(activity_reporter).to receive(:default_log_files).and_return(['/fake/file/path'])
      end

      it 'prints out expected message' do
        output
        expect($stdout).to have_received(:puts).with('EMPTY or NON-EXISTENT: /fake/file/path')
      end
    end

    context 'when file exists' do
      before do
        allow(activity_reporter).to receive(:default_log_files).and_return([error_path])
      end

      context "when file contains today's date" do
        before do
          allow(Time).to receive(:now).and_return(dbl_date)
        end

        context 'when file contains /bundle/ruby|/usr/local/rvm/' do
          it 'prints out expected message' do
            output
            expect($stdout).to have_received(:puts).with("No activity 2017-04-27, DRUID count: 0\n")
          end
        end

        context 'when file does not contain /bundle/ruby|/usr/local/rvm/' do
          before do
            allow(activity_reporter).to receive(:default_log_files).and_return([happy_path])
          end

          context 'when number of druids are returned' do
            it 'prints out expected message w/ only unique druids' do
              output
              expect($stdout).to have_received(:puts).with("DRUID count: 2 for #{date}\n")
            end
          end
        end
      end

      context "when file does not contain today's date" do
        before do
          allow(Time).to receive(:now).and_return('2017-05-01')
        end

        it 'prints out expected message' do
          output
          expect($stdout).to have_received(:puts).with("No activity 2017-05-01, DRUID count: 0\n")
        end
      end
    end
  end
end
