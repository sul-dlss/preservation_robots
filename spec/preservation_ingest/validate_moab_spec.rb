RSpec.describe Robots::SdrRepo::PreservationIngest::ValidateMoab do
  subject(:this_robot) { described_class.new }

  let(:bare_druid) { 'bj102hs9687' }
  let(:druid) { "druid:#{bare_druid}" }

  let(:url) { 'http://localhost:3000' }
  let(:args) { { druid: bare_druid } }

  describe '#perform' do
    before do
      allow(LyberCore::Log).to receive(:debug).with(any_args)
    end

    context 'when the HTTP call is successful' do
      before do
        stub_request(:get, "http://localhost:3000/v1/objects/#{bare_druid}/validate_moab")
          .to_return(status: 200, body: 'ok', headers: {})
      end

      it 'calls GET to /v1/objects/DRUID/validate_moab' do
        this_robot.perform(bare_druid)
      end
    end

    context 'when HTTP fails thrice' do
      before do
        stub_request(:get, "http://localhost:3000/v1/objects/#{bare_druid}/validate_moab")
          .to_return(
            { status: 500, body: '', headers: {} },
            { status: 500, body: '', headers: {} },
            status: 500, body: '', headers: {}
          )
      end

      it 'fails' do
        expect { this_robot.perform(bare_druid) }.to raise_error(Preservation::Client::UnexpectedResponseError)
      end
    end
  end
end
