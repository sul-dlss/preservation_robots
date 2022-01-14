# frozen_string_literal: true

require 'stats_reporter'
describe StatsReporter do
  let(:stats_reporter) { described_class.new }

  describe '.df_output' do
    it 'outputs stats on disk space' do
      output = stats_reporter.df_output
      # for example, this matches '5.0G  2.1G  2.6G  45% /'
      size_regex = '[0-9]+(\.[0-9]+)?[A-Za-z]'
      percent_regex = '[0-9]+\%'
      regex = %r{#{size_regex}.+#{size_regex}.+#{size_regex}.+#{percent_regex}.*\s/}
      expect(output).to match(regex)
    end
  end

  describe '.storage_report_text' do
    it 'constructs a table from the linux df command output' do
      df_shell_output = <<-SHELL
      Filesystem                                       Size  Used Avail Use% Mounted on
      /dev/mapper/rootvg-app                           4.8G  148M  4.5G   4% /opt/app
      ceph-ips:/volumes/preservation/pres-01/ceph-id   1.3P  711T  575T  56% /pres-01
      sf5-sdr:/sdr_services_25                          60T   16T   45T  27% /services-disk25
      SHELL

      table_output = <<-TABLE.strip_heredoc
    +------------------+-------+------+----------+------+----------+
    |    filesystem    | total | used | pct_used | free | pct_free |
    +------------------+-------+------+----------+------+----------+
    | /pres-01         | 1.3P  | 711T | 56%      | 575T | 44%      |
    | /services-disk25 | 60T   | 16T  | 27%      | 45T  | 73%      |
    +------------------+-------+------+----------+------+----------+
      TABLE
      allow(stats_reporter).to receive(:df_output).and_return(df_shell_output)
      expect(stats_reporter.storage_report_text).to eq table_output
    end
  end

  describe '#workflow_report_text' do
    before do
      # this is a little lazy: the error count below
      # demonstrates requests for all workflow steps
      # because 7 steps * 5 objects per step = 35
      stub_request(:get, /workflow/).to_return(status: 200, body: "<objects count='5'>")
    end

    context 'when workflow service responds' do
      let(:table_output) do
        "+----------------------+---------+-------+--------+\n" \
          "|       workflow       | waiting | error | recent |\n" \
          "+----------------------+---------+-------+--------+\n" \
          "| preservationIngestWF | 5       | 35    | 5      |\n" \
          "+----------------------+---------+-------+--------+\n"
      end

      it 'constructs a table from several queries to the workflow service' do
        expect(stats_reporter.workflow_report_text).to eq(table_output)
      end
    end
  end

  describe '.ingest_wf' do
    it 'returns the workflow definition id from the preservationIngestWF xml' do
      expect(stats_reporter.ingest_wf).to eq('preservationIngestWF')
    end
  end

  describe '.ingest_wf_steps' do
    it 'returns an array of process names from the preservationIngestWF xml' do
      expect(stats_reporter.ingest_wf_steps).to eq(%w[start-ingest transfer-object
                                                      validate-bag update-moab validate-moab
                                                      update-catalog complete-ingest])
    end
  end
end
