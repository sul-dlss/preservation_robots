module Preservation
  # Base class for all preservation robots
  class Base
    include LyberCore::Robot

    REPOSITORY = 'sdr'.freeze
    WORKFLOW_NAME = 'preservationIngestWF'.freeze

    def workflow_service
      Dor::Config.workflow.client
    end

    # if command doesn't exit with 0, grabs stdout and stderr and puts them in ruby exception message
    def self.execute_shell_command(command)
      require 'open3'
      stdout, stderr, status = Open3.capture3(command.chomp)
      if status.success? && status.exitstatus.zero?
        stdout
      else
        msg = "Shell command failed: [#{command}] caused by <STDERR = #{stderr}>"
        msg << " STDOUT = #{stdout}" if stdout && stdout.length.positive?
        raise(StandardError, msg)
      end
    rescue SystemCallError => e
      msg = "Shell command failed: [#{command}] caused by #{e.inspect}"
      raise(StandardError, msg)
    end
  end
end
