# frozen_string_literal: true

RSpec.describe Robots::SdrRepo::PreservationIngest::ValidateMoab do
  subject(:this_robot) { described_class.new }

  let(:bare_druid) { 'bj102hs9687' }
  let(:get_url) { "http://localhost:3000/v1/objects/#{bare_druid}/validate_moab" }
  let(:args) { { druid: bare_druid } }

  describe '#perform' do
    context 'when the HTTP call is successful' do
      before do
        stub_request(:get, get_url).to_return(status: 200, body: 'ok', headers: {})
      end

      it 'calls GET to /v1/objects/DRUID/validate_moab' do
        expect { test_perform(this_robot, bare_druid) }.not_to raise_error
      end
    end

    context 'when HTTP fails thrice' do
      before do
        stub_request(:get, get_url)
          .to_return(
            { status: 500, body: '', headers: {} },
            { status: 500, body: '', headers: {} },
            status: 500, body: '', headers: {}
          )
      end

      it 'fails' do
        expect { test_perform(this_robot, bare_druid) }.to raise_error(Preservation::Client::UnexpectedResponseError)
      end
    end
  end
end
