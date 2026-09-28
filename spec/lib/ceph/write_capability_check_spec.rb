# frozen_string_literal: true

require 'tmpdir'

RSpec.describe Ceph::WriteCapabilityCheck do
  subject(:check) { described_class.new(pathname: deposit_bag_pathname, client:, settings:, logger:) }

  let(:logger) { instance_double(Logger, debug: nil, info: nil, warn: nil) }
  let(:mount_root) { Pathname(Dir.mktmpdir).realpath }
  let(:deposit_bag_pathname) { mount_root.join('store1/deposit/hc/243/vw/6417/hc243vw6417') }
  let(:mounts) { [{ mount_point: mount_root.to_s, cephfs_root: '/' }] }
  let(:settings) do
    Config::Options.new.merge!(mounts:, local_hostname: 'preservation-robots-prod-a')
  end
  let(:root_inode_number) { deposit_bag_pathname.stat.ino }
  let(:sessions) do
    [{ 'id' => 4306, 'client_metadata' => { 'hostname' => 'preservation-robots-prod-a.stanford.edu' } },
     { 'id' => 5417, 'client_metadata' => { 'hostname' => 'preservation-robots-prod-b.stanford.edu' } }]
  end
  let(:cached_inodes) { [{ 'ino' => root_inode_number, 'client_caps' => [] }] }
  let(:ranks) { [0] }
  let(:client) { instance_double(Ceph::MdsAdminClient, ranks:, sessions:, dump_tree: cached_inodes) }

  before do
    deposit_bag_pathname.mkpath
  end

  after do
    mount_root.rmtree
  end

  describe '#cephfs_path' do
    it 'translates the local path into the CephFS namespace' do
      expect(check.cephfs_path).to eq '/store1/deposit/hc/243/vw/6417/hc243vw6417'
    end

    context 'when the CephFS mount is rooted below the top of the namespace' do
      let(:mounts) { [{ mount_point: mount_root.to_s, cephfs_root: '/sdr' }] }

      it 'prefixes the path with the CephFS root' do
        expect(check.cephfs_path).to eq '/sdr/store1/deposit/hc/243/vw/6417/hc243vw6417'
      end
    end

    context 'when more than one configured mount point matches' do
      let(:mounts) do
        [{ mount_point: mount_root.to_s, cephfs_root: '/' },
         { mount_point: mount_root.join('store1').to_s, cephfs_root: '/store-one' }]
      end

      it 'uses the most specific one' do
        expect(check.cephfs_path).to eq '/store-one/deposit/hc/243/vw/6417/hc243vw6417'
      end
    end

    context 'when the path is not under any configured mount point' do
      let(:mounts) { [{ mount_point: '/some/other/mount', cephfs_root: '/' }] }

      it 'raises Ceph::Error' do
        expect { check.cephfs_path }
          .to raise_error(Ceph::Error, /is not under any mount point in Settings.ceph.write_capability_check.mounts/)
      end
    end
  end

  describe '#write_capability_holders' do
    context 'when no client holds capabilities on the subtree' do
      it 'reports no holders' do
        expect(check.write_capability_holders).to be_empty
        expect(client).to have_received(:dump_tree)
          .with(cephfs_path: '/store1/deposit/hc/243/vw/6417/hc243vw6417', rank: 0)
      end
    end

    context 'when clients hold only shared and read capabilities' do
      let(:cached_inodes) do
        [{ 'ino' => root_inode_number,
           'client_caps' => [{ 'client_id' => 5417, 'issued' => 'pAsLsXsFscr', 'pending' => 'pAsLsXsFscr' }] }]
      end

      it 'reports no holders' do
        expect(check.write_capability_holders).to be_empty
      end
    end

    context 'when another host is still holding buffered file data' do
      let(:cached_inodes) do
        [{ 'ino' => root_inode_number, 'client_caps' => [] },
         { 'ino' => 1_099_511_628_999,
           'client_caps' => [{ 'client_id' => 5417, 'issued' => 'pAsLsXsFsxcrwb', 'pending' => 'pAsLsXsFsxcrwb' }] }]
      end

      it 'reports the holder and the capabilities it holds' do
        expect(check.write_capability_holders).to eq [
          { ino: 1_099_511_628_999, client_id: 5417, issued: 'pAsLsXsFsxcrwb', pending: 'pAsLsXsFsxcrwb',
            write_grants: %w[Fx Fw Fb] }
        ]
      end
    end

    context 'when the MDS has begun revoking, so only the issued capabilities still allow writes' do
      let(:cached_inodes) do
        [{ 'ino' => root_inode_number,
           'client_caps' => [{ 'client_id' => 5417, 'issued' => 'pAsLsXsFscb', 'pending' => 'pAsLsXsFsc' }] }]
      end

      it 'still reports the holder' do
        expect(check.write_capability_holders).to eq [
          { ino: root_inode_number, client_id: 5417, issued: 'pAsLsXsFscb', pending: 'pAsLsXsFsc',
            write_grants: %w[Fb] }
        ]
      end
    end

    context 'when this host is the one holding the write capabilities' do
      let(:cached_inodes) do
        [{ 'ino' => root_inode_number,
           'client_caps' => [{ 'client_id' => 4306, 'issued' => 'pAsLsXsFsxcrwb', 'pending' => 'pAsLsXsFsxcrwb' }] }]
      end

      it 'ignores them, because reads on this host are already coherent' do
        expect(check.write_capability_holders).to be_empty
      end
    end

    context 'when the MDS does not report the subtree root we just stat\'d' do
      let(:cached_inodes) { [{ 'ino' => 1_099_511_628_999, 'client_caps' => [] }] }

      it 'raises Ceph::Error rather than passing vacuously' do
        expect { check.write_capability_holders }
          .to raise_error(Ceph::Error, /check Settings.ceph.write_capability_check.mounts/)
      end
    end

    context 'when the subtree has many cached inodes' do
      let(:cached_inodes) do
        Array.new(6) do |index|
          { 'ino' => index.zero? ? root_inode_number : 1_099_511_628_000 + index,
            'client_caps' => [{ 'client_id' => 5417, 'issued' => 'pAsLsXsFscr', 'pending' => 'pAsLsXsFscr' }] }
        end
      end

      it "looks up this host's own client ids once, not once per inode" do
        check.write_capability_holders
        expect(client).to have_received(:sessions).with(rank: 0).once
      end
    end

    context 'when the filesystem has more than one MDS rank' do
      let(:ranks) { [0, 1] }

      it 'asks every rank' do
        check.write_capability_holders
        expect(client).to have_received(:dump_tree)
          .with(cephfs_path: '/store1/deposit/hc/243/vw/6417/hc243vw6417', rank: 1)
      end
    end
  end
end
