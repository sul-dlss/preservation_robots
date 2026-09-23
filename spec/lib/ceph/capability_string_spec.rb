# frozen_string_literal: true

RSpec.describe Ceph::CapabilityString do
  subject(:capability_string) { described_class.new(rendered_capabilities) }

  describe '#write?' do
    context 'when the client holds only shared, cache and read capabilities' do
      let(:rendered_capabilities) { 'pAsLsXsFscr' }

      it 'is false' do
        expect(capability_string.write?).to be false
      end
    end

    context 'when the client holds no capabilities at all' do
      let(:rendered_capabilities) { '-' }

      it 'is false' do
        expect(capability_string.write?).to be false
      end
    end

    context 'when the client holds only the pin' do
      let(:rendered_capabilities) { 'p' }

      it 'is false' do
        expect(capability_string.write?).to be false
      end
    end

    context 'when the client holds lazyio but no write capability' do
      let(:rendered_capabilities) { 'pAsLsXsFscrl' }

      it 'is false' do
        expect(capability_string.write?).to be false
      end
    end

    context 'when the client holds buffered file data' do
      let(:rendered_capabilities) { 'pAsLsXsFscb' }

      it 'is true' do
        expect(capability_string.write?).to be true
      end
    end

    context 'when the client holds exclusive auth state' do
      let(:rendered_capabilities) { 'pAsxLsXsFs' }

      it 'is true' do
        expect(capability_string.write?).to be true
      end
    end

    context 'when the client holds exclusive link state' do
      let(:rendered_capabilities) { 'pAsLsxXsFs' }

      it 'is true' do
        expect(capability_string.write?).to be true
      end
    end
  end

  describe '#write_grants' do
    context 'when a writer holds the full set of exclusive and file write capabilities' do
      let(:rendered_capabilities) { 'pAsxLsXsxFsxcrwb' }

      it 'names each write capability held' do
        expect(capability_string.write_grants).to eq %w[Ax Xx Fx Fw Fb]
      end
    end

    context 'when the client may extend EOF' do
      let(:rendered_capabilities) { 'pFa' }

      it 'names the wrextend capability' do
        expect(capability_string.write_grants).to eq %w[Fa]
      end
    end

    context 'when the client holds no write capabilities' do
      let(:rendered_capabilities) { 'pAsLsXsFscr' }

      it 'is empty' do
        expect(capability_string.write_grants).to be_empty
      end
    end
  end

  describe '#grants_by_class' do
    let(:rendered_capabilities) { 'pAsLsXsFscb' }

    it 'splits the string into one entry per capability class' do
      expect(capability_string.grants_by_class).to eq('A' => %w[s], 'L' => %w[s], 'X' => %w[s], 'F' => %w[s c b])
    end
  end

  describe '#pinned?' do
    context 'when the string starts with the pin' do
      let(:rendered_capabilities) { 'pFc' }

      it 'is true' do
        expect(capability_string.pinned?).to be true
      end
    end

    context 'when the string does not start with the pin' do
      let(:rendered_capabilities) { 'Fc' }

      it 'is false' do
        expect(capability_string.pinned?).to be false
      end
    end
  end

  describe '#none?' do
    context 'when the MDS rendered no capabilities' do
      let(:rendered_capabilities) { '-' }

      it 'is true' do
        expect(capability_string.none?).to be true
      end
    end

    context 'when the client holds capabilities' do
      let(:rendered_capabilities) { 'pFc' }

      it 'is false' do
        expect(capability_string.none?).to be false
      end
    end
  end

  describe '#to_s' do
    let(:rendered_capabilities) { 'pAsLsXsFscb' }

    it 'round trips the string it was given' do
      expect(capability_string.to_s).to eq 'pAsLsXsFscb'
    end
  end
end
