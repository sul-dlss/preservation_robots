require 'text-table'
require 'open3'

# Generates text for a report on storage root size and object status
class StatsReporter
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

  def ingest_wf
    'preservationIngestWF'
  end

  def ingest_wf_steps
    %w[start-ingest transfer-object validate-bag
       update-moab update-catalog complete-ingest]
  end

  private

  def storage_mount_lines
    df_output.split("\n").select do |line|
      line.include?('services-disk') || line.include?('pres')
    end
  end

  def parsed_storage_mount_lines
    storage_mount_lines.map do |line|
      split_line = line.split
      {
        total: split_line[1], used: split_line[2],
        remaining: split_line[3], percent_used: split_line[4],
        filesystem: split_line[5], percent_free: "#{(100 - split_line[4].chop.to_i)}%"
      }
    end
  end

  def storage_report_lines
    parsed_storage_mount_lines.map do |h|
      [h.values_at(:filesystem, :total, :used, :percent_used, :remaining, :percent_free)]
    end
  end

  def waiting_count
    # 4th argument is passed from the workflow client to the service which
    # ignores it completely. Can remove once
    # https://github.com/sul-dlss/dor-workflow-client/pull/159 is merged and
    # released and made available in preservation_robots
    workflow_client.count_objects_in_step(ingest_wf, 'start-ingest', 'waiting', nil)
  rescue Dor::WorkflowException => e
    "Error connecting to workflow service: #{e.message}"
  end

  def erroring_count
    ingest_wf_steps.map do |step|
      workflow_client.count_objects_in_step(ingest_wf, step, 'error')
    end.sum
  rescue Dor::WorkflowException => e
    "Error connecting to workflow service: #{e.message}"
  end

  def completed_count
    workflow_client.count_objects_in_step(ingest_wf, 'complete-ingest', 'completed')
  rescue Dor::WorkflowException => e
    "Error connecting to workflow service: #{e.message}"
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
    @workflow_client ||= WorkflowClientFactory.build
  end
end
