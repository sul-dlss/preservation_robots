server 'preservation-robots1-prod.stanford.edu', user: 'pres', roles: %w[web app db monitor]
# # robots2-prod is a warm standby - no resque-pool up but ready to deploy to if needed
# server 'preservation-robots2-prod.stanford.edu', user: 'pres', roles: %w[web app db monitor]

Capistrano::OneTimeKey.generate_one_time_key!

set :deploy_environment, 'prod'
set :default_env, robot_environment: fetch(:deploy_environment)
