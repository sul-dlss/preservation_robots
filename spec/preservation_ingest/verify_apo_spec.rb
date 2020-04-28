describe Robots::SdrRepo::PreservationIngest::VerifyApo do
  subject(:verify_apo) { described_class.new }

  let(:deposit_dir_pathname) { Pathname(File.join(File.dirname(__FILE__), '..', 'fixtures', 'deposit')) }
  let(:deposit_bag_pathname) { Pathname(File.join(deposit_dir_pathname, id)) }
  let(:mock_moab) { instance_double(Moab::StorageObject, deposit_bag_pathname: deposit_bag_pathname) }
  let(:mock_apo_obj) { Dor::AdminPolicyObject.new }
  let(:mock_item_obj) { Dor::Item.new }
  let(:exception_type) { Robots::SdrRepo::PreservationIngest::ItemError }

  before { allow(Stanford::StorageServices).to receive(:find_storage_object).and_return(mock_moab) }

  describe 'relationshipMetadata.xml is in deposit bag' do
    describe 'but APO druid unattainable and' do
      context 'when relationshipMetadata has no <isGovernedBy> element' do
        let(:id) { 'verify-apo-rel-md-no-isGovernedBy' }

        it 'raises ItemError' do
          exp_msg = "Unable to find isGovernedBy node of relationshipMetadata for #{id}"
          expect { verify_apo.perform(id) }.to raise_error(exception_type, exp_msg)
        end
      end

      context 'when relationshipMetadata has no resource attribute for <isGovernedBy> element' do
        let(:id) { 'verify-apo-rel-md-no-resource-attr' }

        it 'raises ItemError' do
          exp_msg = "Unable to find 'resource' attribute for <isGovernedBy> in relationshipMetadata for #{id}"
          expect { verify_apo.perform(id) }.to raise_error(exception_type, exp_msg)
        end
      end

      context 'when relationshipMetadata cannot be parsed' do
        let(:id) { 'verify-apo-rel-md-bad' }

        it 'raises ItemError' do
          rel_md_pathname = deposit_bag_pathname.join('data/metadata/relationshipMetadata.xml')
          exp_msg = "^Unable to parse #{rel_md_pathname} .*#{id}"
          expect { verify_apo.perform(id) }.to raise_error(exception_type, a_string_matching(exp_msg))
        end
      end

    end

    describe 'and APO druid attained' do
      let(:id) { 'verify-apo-has-rel-md-v1' }
      let(:deposit_bag_pathname) { Pathname(File.join(deposit_dir_pathname, id)) }

      it 'if the object exist in Fedora and is an APO type' do
        allow(Dor).to receive(:find).and_return(mock_apo_obj)
        expect { verify_apo.perform(id) }.not_to raise_error
      end

      it 'if the object does not exist in Fedora' do
        exp_msg = "Governing APO object druid:aa000aa0000 not found for #{id}"
        allow(Dor).to receive(:find).and_raise(exception_type, exp_msg)
        expect { verify_apo.perform(id) }.to raise_error(exception_type, exp_msg)
      end

      it 'if the object exists in Fedora but is not an APO type' do
        allow(Dor).to receive(:find).and_return(mock_item_obj)
        exp_msg = "Governing APO object druid:aa000aa0000 not type APO object for #{id}"
        expect { verify_apo.perform(id) }.to raise_error(exception_type, exp_msg)
      end
    end
  end

  describe 'relationshipMetadata.xml is NOT in deposit bag' do
    context 'when deposit version > 1' do
      let(:id) { 'verify-apo-no-rel-md-v2' }

      it 'logs a debug message that test is skipped if deposit version > 1' do
        exp_msg = "APO verification skipped: deposit version > 1 && no relationshipMetadata.xml in bag"
        allow(LyberCore::Log).to receive(:debug)
        verify_apo.perform(id)
        expect(LyberCore::Log).to have_received(:debug).with(exp_msg)
      end
    end
    context 'when deposit version = 1' do
      let(:id) { 'verify-apo-no-rel-md-v1' }

      it 'raises ItemError' do
        exp_msg = "relationshipMetadata.xml not found in deposit bag for #{id}"
        expect { verify_apo.perform(id) }.to raise_error(exception_type, exp_msg)
      end
    end
    context 'when deposit version is unavailable' do
      let(:id) { 'verify-apo-no-rel-md-no-version' }

      it 'raises ItemError' do
        exp_msg = "Unable to determine deposit version for #{id}"
        expect { verify_apo.perform(id) }.to raise_error(exception_type, exp_msg)
      end
    end
  end
end
