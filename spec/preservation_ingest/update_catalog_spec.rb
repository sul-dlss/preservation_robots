# rubocop:disable Metrics/BlockLength

RSpec.describe Robots::SdrRepo::PreservationIngest::UpdateCatalog do
  subject(:update_catalog_obj) { described_class.new }

  let(:bare_druid) { 'bj102hs9687' }
  let(:size) { 2342 }
  let(:version) { 1 }
  let(:strg_root) { 'some/storage/location/from/endpoint/table' }
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
  let(:mock_sos) { [mock_so] }

  before do
    allow(Moab::StorageServices).to receive(:search_storage_objects).and_return(mock_sos)
    allow(mock_sos).to receive(:filter!).and_return(mock_so)
  end

  describe '#perform' do
    before do
      allow(LyberCore::Log).to receive(:debug).with(any_args)
    end

    context 'object is new' do
      context 'when the call is successful' do
        before do
          stub_request(:post, 'http://localhost:3000/v1/catalog')
            .with(
              body: {
                'checksums_validated' => 'true', 'druid' => 'bj102hs9687',
                'incoming_size' => '2342', 'incoming_version' => '1',
                'storage_location' => 'some/storage/location/from/endpoint/table'
              }
            )
            .to_return(status: 200, body: '', headers: {})
        end

        it 'POST to /v1/catalog' do
          update_catalog_obj.perform(bare_druid)
        end
      end

      context 'when HTTP fails twice' do
        before do
          stub_request(:post, 'http://localhost:3000/v1/catalog')
            .with(
              body: {
                'checksums_validated' => 'true', 'druid' => 'bj102hs9687',
                'incoming_size' => '2342', 'incoming_version' => '1',
                'storage_location' => 'some/storage/location/from/endpoint/table'
              }
            )
            .to_return(
              { status: 500, body: '', headers: {} },
              { status: 500, body: '', headers: {} },
              status: 200, body: '', headers: {}
            )
        end

        it 'succeeds' do
          allow(LyberCore::Log).to receive(:warn).twice
          update_catalog_obj.perform(bare_druid)
        end
      end

      context 'when HTTP fails thrice' do
        before do
          stub_request(:post, 'http://localhost:3000/v1/catalog')
            .with(
              body: {
                'checksums_validated' => 'true', 'druid' => 'bj102hs9687',
                'incoming_size' => '2342', 'incoming_version' => '1',
                'storage_location' => 'some/storage/location/from/endpoint/table'
              }
            )
            .to_return(
              { status: 500, body: '', headers: {} },
              { status: 500, body: '', headers: {} },
              status: 500, body: '', headers: {}
            )
        end

        it 'fails' do
          expect { update_catalog_obj.perform(bare_druid) }.to raise_error(Preservation::Client::UnexpectedResponseError)
        end
      end
    end

    context 'object already exists' do
      let(:version) { 3 }

      before do
        stub_request(:patch, 'http://localhost:3000/v1/catalog/bj102hs9687')
          .with(
            body: {
              'checksums_validated' => 'true', 'druid' => 'bj102hs9687',
              'incoming_size' => '2342', 'incoming_version' => '3',
              'storage_location' => 'some/storage/location/from/endpoint/table'
            }
          )
          .to_return(status: 200, body: '', headers: {})
      end

      it 'PATCH to /v1/catalog/:druid' do
        update_catalog_obj.perform(bare_druid)
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
