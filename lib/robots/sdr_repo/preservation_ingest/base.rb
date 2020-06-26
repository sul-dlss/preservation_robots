# Robot package to run under multiplexing infrastructure
module Robots
  # Use DorRepo/SdrRepo to match the workflow repo (and avoid name collision with Dor module)
  module SdrRepo
    # The workflow package name - match the actual workflow name, minus ending WF (using CamelCase)
    module PreservationIngest
      # Base class for all preservation robots
      class Base
        include LyberCore::Robot

        WORKFLOW_NAME = 'preservationIngestWF'.freeze

        attr_reader :druid

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

        def workflow_service
          @workflow_service ||= WorkflowClientFactory.build
        end

        private

        def moab_object
          # @moab_object ||= PreservationClient::Client.objects.primary_moab_location(druid: druid)
          # search_storage_objects
          @moab_object = Stanford::StorageServices.search_storage_objects(druid, true).first
          # @moab_object = @moab_objects.first
        #   @moab_objects.each do |moab|
        #     @moab_object ||= moab if moab.storage_root == PreservationClient::Client.objects.primary_moab_location(druid: druid)
        #   end
        end

        def deposit_bag_pathname
          @deposit_bag_pathname ||= moab_object.deposit_bag_pathname
        end
      end
    end
  end
end
