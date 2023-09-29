# frozen_string_literal: true

# generates text for a report on druid count and logs
class ActivityReporter
  DRUID_REGEXP = '[[:lower:]]{2}\\d{3}[[:lower:]]{2}\\d{4}'

  def output(log_files = default_log_files)
    today = Time.now.to_date.to_s
    counter = {}
    puts '*' * 20
    log_files.each do |file|
      unless File.exist?(file) && File.size(file).positive?
        puts "EMPTY or NON-EXISTENT: #{file}"
        next
      end
      extract_druid(file, today, counter)
      druid_counts = counter.keys.size
      if druid_counts.zero?
        puts "No activity #{today}, DRUID count: #{druid_counts}\n"
      else
        puts "DRUID count: #{druid_counts} for #{today}\n"
      end
    end
  end

  def extract_druid(file, today, counter)
    File.readlines(file).each do |line|
      line =~ /#{today}/ || next
      line =~ %r{/bundle/ruby|/usr/local/rvm/} && next
      druid = line.match(/Finished.*(#{DRUID_REGEXP})/) || next
      counter[druid] = 1
    end
  end

  def default_log_files
    Reporter.default_log_files
  end
end
