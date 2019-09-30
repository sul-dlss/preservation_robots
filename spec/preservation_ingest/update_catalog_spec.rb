describe Robots::SdrRepo::PreservationIngest::UpdateCatalog do
  subject(:update_catalog_obj) { described_class.new }

  let(:bare_druid) { 'bj102hs9687' }
  let(:size) { 2342 }
  let(:version) { 1 }
  let(:strg_root) { "some/storage/location/from/endpoint/table" }
  let(:faraday_dbl) { class_double(Faraday) }
  let(:url) { 'http://localhost:3000' }
  let(:args) do
    {
      druid: bare_druid,
      incoming_version: version,
      incoming_size: size,
      storage_location: strg_root,
      checksums_validated: true
    }
  end
  let(:mock_so) do
    instance_double(Moab::StorageObject, object_pathname: instance_double(Pathname), size: size, storage_root: strg_root, current_version_id: version)
  end

  before do
    allow(Moab::StorageServices).to receive(:find_storage_object).and_return(mock_so)
  end

  describe '#perform' do
    before do
      allow(LyberCore::Log).to receive(:debug).with(any_args)
      allow(Faraday).to receive(:new).with(url: url).and_return(faraday_dbl)
    end

    context 'object is new' do
      it 'POST to /catalog' do
        response = instance_double(Faraday::Response, status: 201)
        expect(faraday_dbl).to receive(:post).with('/catalog', args).and_return(response)
        expect(faraday_dbl).not_to receive(:patch)
        update_catalog_obj.perform(bare_druid)
      end

      it 'succeeds when HTTP fails twice' do
        response = instance_double(Faraday::Response, status: 201)
        allow(LyberCore::Log).to receive(:warn).twice
        expect(faraday_dbl).to receive(:post).with('/catalog', args).and_raise(Faraday::Error.new('foo')).twice
        expect(faraday_dbl).to receive(:post).with('/catalog', args).once.and_return(response)
        allow(faraday_dbl).to receive(:patch)
        update_catalog_obj.perform(bare_druid)
        expect(faraday_dbl).not_to have_received(:patch)
        expect(LyberCore::Log).to have_received(:warn).twice
      end

      it 'fails when HTTP fails thrice' do
        allow(faraday_dbl).to receive(:post).with('/catalog', args).and_raise(Faraday::Error.new('foo')).exactly(3).times
        expect { update_catalog_obj.perform(bare_druid) }.to raise_error(Faraday::Error)
      end
    end

    context 'object already exists' do
      let(:version) { 3 }

      it 'PATCH to /catalog/:druid' do
        response = instance_double(Faraday::Response, status: 409)
        expect(faraday_dbl).to receive(:patch).with("/catalog/#{bare_druid}", args).and_return(response)
        update_catalog_obj.perform(bare_druid)
      end
    end
  end

  describe '#conn' do
    it 'calls Settings.preservation_catalog.url' do
      response = instance_double(Faraday::Response, status: 201)
      expect(Faraday).to receive(:new).with(url: Settings.preservation_catalog.url).and_return(faraday_dbl)
      allow(faraday_dbl).to receive(:post).with('/catalog', args).and_return(response)
      update_catalog_obj.perform(bare_druid)
    end
  end
end
