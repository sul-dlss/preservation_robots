# generates text for a report on storage root size and object status
class StatsReporter

  require 'text-table'
  require 'open3'

  def storage_report_text
    head = %w[filesystem total used pct_used free pct_free]
    Text::Table.new(head: head, rows: storage_report_lines).to_s
  end

  def workflow_report_text
    head = %w[workflow waiting error recent]
    Text::Table.new(head: head, rows: workflow_report_lines).to_s
  end

  def df_output
    stdout_str, _status = Open3.capture2('df -h')
    stdout_str
  end

  def repository
    workflow_xml.at_xpath('//workflow-def/@repository').value
  end

  def ingest_wf
    workflow_xml.at_xpath('//workflow-def/@id').value
  end

  def ingest_wf_steps
    workflow_xml.xpath('//process/@name').map(&:value)
  end

  private

  def storage_mount_lines
    df_output.split("\n").select { |line| line.include?('services-disk') }
  end

  def parsed_storage_mount_lines
    storage_mount_lines.map do |line|
      split_line = line.split
      {
        total: split_line[0], used: split_line[1],
        remaining: split_line[2], percent_used: split_line[3],
        filesystem: split_line[4], percent_free: "#{(100 - split_line[3].chop.to_i)}%"
      }
    end
  end

  def storage_report_lines
    parsed_storage_mount_lines.map do |h|
      [h.values_at(:filesystem, :total, :used, :percent_used, :remaining, :percent_free)]
    end
  end

  def workflow_xml
    @workflow_xml ||= File.open('config/workflows/sdr/preservationIngestWF') { |f| Nokogiri::XML(f) }
  end

  def waiting_count
    workflow_client.count_objects_in_step(ingest_wf, 'start-ingest',
                                          'waiting', repository)
  rescue Dor::WorkflowException => exception
    "Error connecting to workflow service: #{exception.message}"
  end

  def erroring_count
    ingest_wf_steps.map do |step|
      workflow_client.count_objects_in_step(ingest_wf, step,
                                            'error', repository)
    end.sum
  rescue Dor::WorkflowException => exception
    "Error connecting to workflow service: #{exception.message}"
  end

  def completed_count
    workflow_client.count_objects_in_step(ingest_wf, 'complete-ingest',
                                          'completed', repository)
  rescue Dor::WorkflowException => exception
    "Error connecting to workflow service: #{exception.message}"
  end

  def workflow_report_lines
    [[
      ingest_wf,
      waiting_count,
      erroring_count,
      completed_count
    ]]
  end

  def workflow_client
    Dor::Config.workflow.client
  end
end
