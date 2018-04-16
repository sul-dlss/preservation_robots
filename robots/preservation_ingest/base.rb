# Robot package to run under multiplexing infrastructure
module Robots
  # Use DorRepo/SdrRepo to match the workflow repo (and avoid name collision with Dor module)
  module SdrRepo
    # The workflow package name - match the actual workflow name, minus ending WF (using CamelCase)
    module PreservationIngest
      # Base class for all preservation robots
      class Base < LyberCore::Base
        REPOSITORY = 'sdr'.freeze
        WORKFLOW_NAME = 'preservationIngestWF'.freeze

        attr_reader :druid

        # @param [String] a concrete class' robot name
        def self.robot_name
          return const_get(:ROBOT_NAME) if const_defined?(:ROBOT_NAME)
          raise NotImplementedError, "specify ROBOT_NAME or implement self.robot_name in subclass"
        end

        # a constructor
        def self.worker
          new(REPOSITORY, WORKFLOW_NAME, robot_name)
        end

        # if command doesn't exit with 0, grabs stdout and stderr and puts them in ruby exception message
        def self.execute_shell_command(command)
          require 'open3'
          stdout, stderr, status = Open3.capture3(command.chomp)
          if status.success? && status.exitstatus.zero?
            stdout
          else
            msg = "Shell command failed: [#{command}] caused by <STDERR = #{stderr}>"
            msg << " STDOUT = #{stdout}" if stdout.try(:length).positive?
            raise(StandardError, msg)
          end
        rescue SystemCallError => e
          msg = "Shell command failed: [#{command}] caused by #{e.inspect}"
          raise(StandardError, msg)
        end

        private

        def moab_object
          @moab_object ||= Stanford::StorageServices.find_storage_object(druid, true)
        end

        def deposit_bag_pathname
          @deposit_bag_pathname ||= moab_object.deposit_bag_pathname
        end
      end
    end
  end
end
