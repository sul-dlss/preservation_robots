# Robot package to run under multiplexing infrastructure
module Robots
  # Use DorRepo/SdrRepo to match the workflow repo (and avoid name collision with Dor module)
  module SdrRepo
    # The workflow package name - match the actual workflow name, minus ending WF (using CamelCase)
    module PreservationIngest
      # ItemError wraps a causal exception, creating a new exception
      #   that usually terminates processing of the current item
      class ItemError < StandardError
      end
    end
  end
end
