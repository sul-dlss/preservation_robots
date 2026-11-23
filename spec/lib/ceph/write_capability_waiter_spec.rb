# frozen_string_literal: true

require 'tmpdir'

RSpec.describe Ceph::WriteCapabilityWaiter do
  subject(:waiter) { described_class.new(pathnames:, settings:, client:, logger:) }

  let(:logger) { instance_double(Logger, debug: nil, info: nil, warn: nil) }
  let(:client) { instance_double(Ceph::MdsAdminClient) }
  let(:mount_root) { Pathname(Dir.mktmpdir).realpath }
  let(:deposit_bag_pathname) { mount_root.join('store1/deposit/kp/812/rn/5093/kp812rn5093') }
  let(:moab_object_pathname) { mount_root.join('store1/sdr2objects/kp/812/rn/5093/kp812rn5093') }
  let(:pathnames) { [deposit_bag_pathname, moab_object_pathname] }
  let(:existing_pathnames) { pathnames }
  let(:enabled) { true }
  # poll_interval is 0 so that the polling examples below do not actually pause
  let(:settings) { Config::Options.new.merge!(enabled:, max_wait: 10, poll_interval: 0) }
  let(:holders) do
    [{ ino: 1_099_511_628_999, client_id: 5417, issued: 'pAsLsXsFsxcrwb', pending: 'pAsLsXsFsxcrwb',
       write_grants: %w[Fx Fw Fb] }]
  end
  let(:check) { instance_double(Ceph::WriteCapabilityCheck) }

  before do
    existing_pathnames.each(&:mkpath)
    allow(Ceph::WriteCapabilityCheck).to receive(:new).and_return(check)
    allow(check).to receive(:write_capability_holders).and_return([])
    allow(Honeybadger).to receive(:notify)
  end

  after do
    mount_root.rmtree
  end

  describe '#wait' do
    context 'when the check is disabled' do
      let(:enabled) { false }

      it 'does not query Ceph at all' do
        waiter.wait
        expect(Ceph::WriteCapabilityCheck).not_to have_received(:new)
      end
    end

    context 'when no other host holds write capabilities' do
      it 'returns without waiting' do
        expect { waiter.wait }.not_to raise_error
        expect(logger).not_to have_received(:info)
      end

      it 'builds a check for each path' do
        waiter.wait
        expect(Ceph::WriteCapabilityCheck).to have_received(:new)
          .with(pathname: deposit_bag_pathname, client:, settings:, logger:)
      end
    end

    context 'when the write capabilities are released while we wait' do
      before do
        allow(check).to receive(:write_capability_holders).and_return(holders, holders, [], [])
      end

      it 'polls until they clear and then returns' do
        expect { waiter.wait }.not_to raise_error
        expect(logger).to have_received(:info).with(/waiting 0s for write capabilities on .+ to be released/).once
      end
    end

    context 'when the write capabilities are never released' do
      before do
        allow(check).to receive(:write_capability_holders).and_return(holders)
        allow(Process).to receive(:clock_gettime).and_call_original
        # Start the clock, one poll inside the window, then far past the deadline.
        allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(0.0, 5.0, 1_000.0)
      end

      it 'raises Ceph::WriteCapabilitiesHeldError naming the holder' do
        expect { waiter.wait }
          .to raise_error(Ceph::WriteCapabilitiesHeldError,
                          /gave up after 10s.*inode 1099511628999 held by client 5417 \(Fx Fw Fb\)/m)
      end
    end

    context 'when we are unwilling to wait at all' do
      let(:settings) { Config::Options.new.merge!(enabled: true, max_wait: 0, poll_interval: 0) }

      before do
        allow(check).to receive(:write_capability_holders).and_return(holders)
      end

      it 'checks once and raises' do
        expect { waiter.wait }.to raise_error(Ceph::WriteCapabilitiesHeldError)
        expect(logger).not_to have_received(:info)
      end
    end

    context 'when Ceph cannot be queried' do
      let(:error) { Ceph::Error.new('access denied') }

      before do
        allow(check).to receive(:write_capability_holders).and_raise(error)
      end

      it 'proceeds rather than failing the step' do
        expect { waiter.wait }.not_to raise_error
      end

      it 'reports the failure so a misconfigured check does not pass silently' do
        waiter.wait
        expect(Honeybadger).to have_received(:notify)
          .with(error, context: { pathnames: "#{deposit_bag_pathname}, #{moab_object_pathname}" })
      end
    end

    context 'when a path is not visible on this host' do
      let(:missing_pathname) { mount_root.join('store1/sdr2objects/kp/812/rn/5093/kp812rn5093') }
      let(:pathnames) { [deposit_bag_pathname, missing_pathname] }
      let(:existing_pathnames) { [deposit_bag_pathname] }

      it 'warns and checks only the paths it can resolve' do
        waiter.wait
        expect(logger).to have_received(:warn).with(/#{missing_pathname}: it does not exist/)
        expect(Ceph::WriteCapabilityCheck).to have_received(:new).once
      end
    end
  end
end
