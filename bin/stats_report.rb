#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../lib/stats_reporter')
require File.expand_path(File.dirname(__FILE__) + '/../config/boot')

stats_reporter = StatsReporter.new
puts "Stats compiled on #{Time.now.to_date}"
puts "Storage stats for mounts on #{Socket.gethostname}:"
puts stats_reporter.storage_report_text
puts "Workflow stats:"
puts stats_reporter.workflow_report_text
