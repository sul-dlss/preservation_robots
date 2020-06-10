require 'error_reporter'
describe ErrorReporter do
  let(:error_reporter) { described_class.new }
  let(:tables) { error_reporter.table_generator }
  let(:error_table) { tables.first }
  let(:warning_table) { tables.second }
  let(:date) { '2017-04-27' }
  let(:dbl_date) { instance_double(Time, to_date: date) }
  let(:base_path) { "#{Dir.pwd}/spec/fixtures" }
  let(:error_path) { "#{base_path}/log/sdr_preservationIngestWF_transfer-object.log" }
  let(:warn_path) { "#{base_path}/log/sdr_preservationIngestWF_validate-bag.log" }

  describe '#table_generator' do
    context 'file does not exist' do
      before do
        allow(error_reporter).to receive(:default_log_files).and_return(['/fake/file/path'])
        allow(STDOUT).to receive(:puts).with('EMPTY or NON-EXISTENT: /fake/file/path')
      end

      it 'returns an empty array' do
        expect(error_table.rows).to be_empty
        expect(warning_table.rows).to be_empty
      end
    end

    context 'file exists' do
      before do
        allow(error_reporter).to receive(:default_log_files).and_return([error_path])
      end

      context 'file contains todays date' do
        before do
          allow(Time).to receive(:now).and_return(dbl_date)
        end

        context 'file contains ERROR' do
          let(:info_msg) { 'INFO [2017-04-27 11:07:36] (17545)  :: druid:db274ff1758 processing' }
          let(:error_msg) { 'ERROR [2017-04-27 11:07:37] (17541)  :: Some Random Error' }

          it 'outputs table' do
            expect(error_table.rows).to eq [[error_path, info_msg, date], [error_path, error_msg, date]]
          end
        end

        context 'file does not contain ERROR' do
          before do
            allow(error_reporter).to receive(:default_log_files).and_return([warn_path])
          end

          it 'does not output table' do
            expect(error_table.rows).to be_empty
          end
        end

        context 'file contains WARN' do
          before do
            allow(error_reporter).to receive(:default_log_files).and_return([warn_path])
          end

          let(:warn_msg) { 'WARN [2017-04-27 11:07:37] (17541)  :: Some Random Warning' }

          it 'outputs table' do
            expect(warning_table.rows).to eq [[warn_path, warn_msg, date]]
          end
        end

        context 'file does not contain WARN' do
          before do
            allow(error_reporter).to receive(:default_log_files).and_return([error_path])
          end

          it 'does not output table' do
            expect(warning_table.rows).to be_empty
          end
        end
      end

      context 'file does not contain todays date' do
        it 'does not output table' do
          expect(warning_table.rows).to be_empty
          expect(error_table.rows).to be_empty
        end
      end
    end
  end
end
