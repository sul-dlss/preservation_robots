# generates text for a report on errors and warning in robot
class ErrorReporter
  require 'text-table'
  require 'fileutils'
  require 'date'

  def output
    table_generator.each { |table| puts table.to_s unless table.rows.empty? }
  end

  def table_generator(log_files=default_log_files)
    stack = []
    today = Time.now.to_date.to_s

    log_files.each do |file|
      unless File.exist?(file) && File.size(file) > 0
        puts "EMPTY or NON-EXISTENT: #{file}"
        next
      end
      File.readlines(file).each do |line|
        line =~ /#{today}/ || next
        line.chomp!
        stack << line
        if line =~ /ERROR/
          error_table.rows << [file, stack.shift, today] if stack.size > 1
          error_table.rows << [file, line, today]
          next
        end
        if line =~ /WARN/
          next if line =~ /resque-signals/
          warning_table.rows << [file, line, today]
        end
        stack.pop if stack.size > 2
      end
    end
    [error_table, warning_table]
  end

  private

  def error_table
    @error_table ||= begin
      table = Text::Table.new
      table.head = %w[workflow errors timestamp]
      table
    end
  end

  def warning_table
    @warning_table ||= begin
      table = Text::Table.new
      table.head = %w[workflow warnings timestamp]
      table
    end
  end

  def default_log_files
    [
      "sdr_preservationIngestWF_transfer-object.log",
      "sdr_preservationIngestWF_validate-bag.log",
      "sdr_preservationIngestWF_verify-apo.log",
      "sdr_preservationIngestWF_update-moab.log",
      "sdr_preservationIngestWF_update-catalog.log",
      "sdr_preservationIngestWF_complete-ingest.log"
    ].map { |file| "#{Dir.pwd}/log/#{file}" }
  end
end
