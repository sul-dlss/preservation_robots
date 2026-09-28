# frozen_string_literal: true

RSpec.describe Ceph::MdsAdminClient do
  subject(:client) { described_class.new(settings:, logger:) }

  let(:logger) { instance_double(Logger, debug: nil, info: nil, warn: nil) }
  let(:cli_settings) do
    { executable: 'ceph', conf: nil, name: nil, keyring: nil, connect_timeout: 30 }
  end
  let(:write_capability_check_settings) { { filesystem_name: 'sdr', ranks: [0] } }
  let(:settings) do
    Config::Options.new.merge!(cli: cli_settings, write_capability_check: write_capability_check_settings)
  end
  let(:status) { instance_double(Process::Status, success?: true, exitstatus: 0) }
  let(:stdout) { '{}' }
  let(:stderr) { '' }

  before do
    allow(Open3).to receive(:capture3).and_return([stdout, stderr, status])
  end

  describe '#ranks' do
    context 'when ranks are configured' do
      it 'uses them without asking the cluster' do
        expect(client.ranks).to eq [0]
        expect(Open3).not_to have_received(:capture3)
      end
    end

    context 'when ranks are not configured' do
      let(:write_capability_check_settings) { { filesystem_name: 'sdr', ranks: [] } }
      let(:stdout) { { mdsmap: { in: [0, 1] } }.to_json }

      it 'asks the cluster which ranks are in' do
        expect(client.ranks).to eq [0, 1]
        expect(Open3).to have_received(:capture3).with('ceph', '--format', 'json', '--connect-timeout', '30',
                                                       'fs', 'get', 'sdr')
      end
    end

    context 'when the cluster reports no ranks in' do
      let(:write_capability_check_settings) { { filesystem_name: 'sdr', ranks: [] } }
      let(:stdout) { { mdsmap: { in: [] } }.to_json }

      it 'raises Ceph::Error' do
        expect { client.ranks }.to raise_error(Ceph::Error, /no MDS ranks are in for CephFS filesystem 'sdr'/)
      end
    end
  end

  describe '#dump_tree' do
    let(:stdout) { { inodes: [{ ino: 1_099_511_628_123, client_caps: [] }] }.to_json }

    it 'tells the MDS rank to dump the subtree and returns its inodes' do
      expect(client.dump_tree(cephfs_path: '/store1/deposit/hc243vw6417', rank: 0))
        .to eq [{ 'ino' => 1_099_511_628_123, 'client_caps' => [] }]
      expect(Open3).to have_received(:capture3).with('ceph', '--format', 'json', '--connect-timeout', '30',
                                                     'tell', 'mds.sdr:0', 'dump', 'tree',
                                                     '/store1/deposit/hc243vw6417')
    end

    context 'when the subtree is not in the MDS cache' do
      let(:stdout) { '' }
      let(:stderr) { "inode for path '/store1/deposit/hc243vw6417' is not in cache" }

      it 'reports no inodes' do
        expect(client.dump_tree(cephfs_path: '/store1/deposit/hc243vw6417', rank: 0)).to eq []
      end
    end

    context 'when the ceph command fails' do
      let(:status) { instance_double(Process::Status, success?: false, exitstatus: 13) }
      let(:stderr) { 'Error EACCES: access denied' }

      it 'raises Ceph::Error' do
        expect { client.dump_tree(cephfs_path: '/store1/deposit/hc243vw6417', rank: 0) }
          .to raise_error(Ceph::Error, /exited 13: Error EACCES: access denied/)
      end
    end

    context 'when the ceph command emits something other than JSON' do
      let(:stdout) { 'not json' }

      it 'raises Ceph::Error' do
        expect { client.dump_tree(cephfs_path: '/store1/deposit/hc243vw6417', rank: 0) }
          .to raise_error(Ceph::Error, /unparseable response from ceph/)
      end
    end

    context 'when the ceph executable is not installed' do
      before do
        allow(Open3).to receive(:capture3).and_raise(Errno::ENOENT, 'ceph')
      end

      it 'raises Ceph::Error' do
        expect { client.dump_tree(cephfs_path: '/store1/deposit/hc243vw6417', rank: 0) }
          .to raise_error(Ceph::Error, /unable to run tell mds.sdr:0 dump tree/)
      end
    end
  end

  describe '#sessions' do
    let(:stdout) do
      [{ id: 4306, client_metadata: { hostname: 'preservation-robots-prod-a' } }].to_json
    end

    it 'lists the client sessions the MDS rank is holding' do
      expect(client.sessions(rank: 1))
        .to eq [{ 'id' => 4306, 'client_metadata' => { 'hostname' => 'preservation-robots-prod-a' } }]
      expect(Open3).to have_received(:capture3).with('ceph', '--format', 'json', '--connect-timeout', '30',
                                                     'tell', 'mds.sdr:1', 'session', 'ls')
    end
  end

  describe 'the ceph invocation' do
    let(:cli_settings) do
      { executable: '/usr/bin/ceph', conf: '/etc/ceph/ceph.conf', name: 'client.preservation_robots',
        keyring: '/etc/ceph/ceph.client.preservation_robots.keyring', connect_timeout: 5 }
    end

    it 'passes the configured cluster connection options through' do
      client.sessions(rank: 0)
      expect(Open3).to have_received(:capture3).with('/usr/bin/ceph', '--format', 'json',
                                                     '--conf', '/etc/ceph/ceph.conf',
                                                     '--name', 'client.preservation_robots',
                                                     '--keyring', '/etc/ceph/ceph.client.preservation_robots.keyring',
                                                     '--connect-timeout', '5',
                                                     'tell', 'mds.sdr:0', 'session', 'ls')
    end
  end
end
