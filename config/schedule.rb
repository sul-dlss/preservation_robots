# to let whenever access settings:
require File.expand_path(File.dirname(__FILE__) + "/boot")

every 5.minutes do
  # cannot use :output with Hash/String because we don't want append behavior
  set :output, (proc { '> log/verify.log 2> log/cron.log' })
  set :environment_variable, 'ROBOT_ENVIRONMENT'
  rake 'robots:verify'
end

every :sunday, at: '4am' do
  set :output, nil
  set :environment_variable, 'ROBOT_ENVIRONMENT'
  rake 'generate_storage_stats'
  rake 'generate_wf_stats'
end

every :sunday, at: '5am' do
  set :output, nil
  command "/bin/cat /var/log/preservation_robots/storage_stats.log | mail -s 'Weekly preservation storage stats' #{Settings.email_addresses.discussion_list}"
  command "/bin/cat /var/log/preservation_robots/wf_stats.log | mail -f 'Weekly preservation workflow stats' #{Settings.email_addresses.discussion_list}"
end

every 1.day, at: '5am' do
  set :output, nil
  rake 'preservation_errors', mailto: Settings.email_addresses.user_list
end

every 1.day, at: '5:10am' do
  set :output, nil
  rake 'preservation_logs', mailto: Settings.email_addresses.user_list
end
