require 'rake'
require 'robot-controller/tasks'

task :environment do
  require_relative 'config/boot'
end

task default: :ci

desc 'run continuous integration suite (tests & rubocop)'
task ci: [:spec, :rubocop]

begin
  require 'rspec/core/rake_task'
  desc 'Run RSpec'
  RSpec::Core::RakeTask.new(:spec)
rescue LoadError
  desc 'Run RSpec'
  task :spec do
    abort 'Please install the rspec gem to run tests.'
  end
end

begin
  require 'rubocop/rake_task'
  desc 'Run rubocop'
  RuboCop::RakeTask.new
rescue LoadError
  desc 'Run rubocop'
  task :rubocop do
    abort 'Please install the rubocop gem to run rubocop.'
  end
end

desc 'Generate all stats'
task generate_stats: [:environment] do
  require File.expand_path(File.dirname(__FILE__) + '/lib/stats_reporter')
  stats_reporter = StatsReporter.new
  complete_report = <<-REPORT.strip_heredoc
Stats compiled on #{Time.now.to_date}
Storage stats for mounts on #{Socket.gethostname}:
#{stats_reporter.storage_report_text}
Workflow stats:
#{stats_reporter.workflow_report_text}
  REPORT
  File.open("#{ROBOT_ROOT}/log/weekly_stats.log", 'w') { |f| f.write(complete_report) }
end

desc 'Generate storage stats'
task generate_storage_stats: [:environment] do
  require File.expand_path(File.dirname(__FILE__) + '/lib/stats_reporter')
  stats_reporter = StatsReporter.new
  storage_report = <<-REPORT.strip_heredoc
Stats compiled on #{Time.now.to_date}
Storage stats for mounts on #{Socket.gethostname}:
#{stats_reporter.storage_report_text}
  REPORT
  File.open("#{ROBOT_ROOT}/log/storage_stats.log", 'w') { |f| f.write(storage_report) }
end

desc 'Generate workflow stats'
task generate_wf_stats: [:environment] do
  require File.expand_path(File.dirname(__FILE__) + '/lib/stats_reporter')
  stats_reporter = StatsReporter.new
  wf_report = <<-REPORT.strip_heredoc
Stats compiled on #{Time.now.to_date}
Workflow stats:
#{stats_reporter.workflow_report_text}
  REPORT
  File.open("#{ROBOT_ROOT}/log/wf_stats.log", 'w') { |f| f.write(wf_report) }
end

desc 'get error and warning messages for each WF step'
task preservation_errors: [:environment] do
  require File.expand_path(File.dirname(__FILE__) + '/lib/error_reporter')
  error_reporter = ErrorReporter.new
  error_reporter.output
end

desc 'get druid counts for each WF step'
task preservation_logs: [:environment] do
  require File.expand_path(File.dirname(__FILE__) + '/lib/activity_reporter')
  activity_reporter = ActivityReporter.new
  activity_reporter.output
end
