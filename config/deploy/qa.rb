server 'preservation-robots1-qa.stanford.edu', user: 'pres', roles: %w[web app db]
# robots2-qa is a warm standby - no resque-pool up but ready to deploy to if needed
# server 'preservation-robots2-qa.stanford.edu', user: 'pres', roles: %w[web app db]

Capistrano::OneTimeKey.generate_one_time_key!

set :deploy_environment, 'qa'
set :default_env, robot_environment: fetch(:deploy_environment)
