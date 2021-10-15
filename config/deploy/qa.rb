# robots1-qa is temporarily out of service, robots2-qa picks up the slack
# server 'preservation-robots1-qa.stanford.edu', user: 'pres', roles: %w[web app db]
server 'preservation-robots2-qa.stanford.edu', user: 'pres', roles: %w[web app db]

Capistrano::OneTimeKey.generate_one_time_key!

set :deploy_environment, 'qa'
set :default_env, robot_environment: fetch(:deploy_environment)
