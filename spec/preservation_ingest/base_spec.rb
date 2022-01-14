# frozen_string_literal: true

RSpec.describe Robots::SdrRepo::PreservationIngest::Base do
  describe '.execute_shell_command' do
    it 'returns stdout for success' do
      cmd = 'echo "hello world!"'
      expect(described_class.execute_shell_command(cmd)).to eq "hello world!\n"
    end

    it 'return code != 0 raises StandardError with stdout and stderr info' do
      cmd = 'false'
      exp_msg = Regexp.new(Regexp.escape('Shell command failed: [false] caused by <STDERR = >'))
      expect { described_class.execute_shell_command(cmd) }.to raise_error(StandardError, a_string_matching(exp_msg))
    end

    it 'SystemCallError raises StandardError with Errno info' do
      cmd = 'wingnut-is-my-cat'
      exp_msg = 'Shell command failed: [wingnut-is-my-cat] caused by #<Errno::ENOENT: No such file or directory'
      exp_msg = Regexp.new(Regexp.escape(exp_msg))
      expect { described_class.execute_shell_command(cmd) }.to raise_error(StandardError, a_string_matching(exp_msg))
    end
  end
end
