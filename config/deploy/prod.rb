# frozen_string_literal: true

server 'preservation-robots1-prod.stanford.edu', user: 'pres', roles: %w[web app db worker]
# # robots2-prod is a warm standby - no sidekiq up but ready to deploy to if needed
# server 'preservation-robots2-prod.stanford.edu', user: 'pres', roles: %w[web app db worker]

set :deploy_environment, 'prod'
set :default_env, robot_environment: fetch(:deploy_environment)
