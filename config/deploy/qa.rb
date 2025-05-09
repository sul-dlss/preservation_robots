# frozen_string_literal: true

server 'preservation-robots1-qa.stanford.edu', user: 'pres', roles: %w[web app db worker]
# robots2-qa is a warm standby - no sidekiq up but ready to deploy to if needed
# server 'preservation-robots2-qa.stanford.edu', user: 'pres', roles: %w[web app db worker]

set :deploy_environment, 'qa'
set :default_env, robot_environment: fetch(:deploy_environment)
