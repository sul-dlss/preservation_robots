# while rebuilding robots1 as Ubuntu, robots2 picks up the slack
# server 'preservation-robots1-prod.stanford.edu', user: 'pres', roles: %w[web app db monitor]
server 'preservation-robots2-prod.stanford.edu', user: 'pres', roles: %w[web app db monitor]

Capistrano::OneTimeKey.generate_one_time_key!

set :deploy_environment, 'prod'
set :default_env, robot_environment: fetch(:deploy_environment)
