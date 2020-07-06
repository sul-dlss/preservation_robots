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
          # StorageServices.search_storage_objects won't return us what we want if the object version is
          # still mid-deposit in the preservation workflow -- see https://github.com/sul-dlss/moab-versioning/issues/167
          # as such, use it to see if there are multiple copies already preserved among different storage roots.
          # if there are, use the location for the primary according to pres cat to pick the storage location to update.
          # if there are not multiple copies already preserved, use find_storage_object and include the deposit
          # folders -- this will return a storage object pointing to the correct storage root (which will be the last one
          # listed in the configs if this is the first version being preserved).
          existing_moabs = Stanford::StorageServices.search_storage_objects(druid)
          @moab_object ||=
            if existing_moabs.size > 1
              # if we see more than one among the storage roots, ask pres cat to choose a primary
              existing_moabs.find { |moab| moab.object_pathname.to_s.start_with?(primary_moab_location) }
            else
              Stanford::StorageServices.find_storage_object(druid, true)
            end
        rescue Preservation::Client::NotFoundError
          raise "#{druid} - Multiple copies of Moab exist among storage roots, but Preservation Catalog has no primary location for it"
        end

        # @raise [Preservation::Client::NotFoundError]
        def primary_moab_location
          @primary_moab_location ||= Preservation::Client.objects.primary_moab_location(druid: druid)
        end

        def deposit_bag_pathname
          @deposit_bag_pathname ||= moab_object.deposit_bag_pathname
        end
      end
    end
  end
end
