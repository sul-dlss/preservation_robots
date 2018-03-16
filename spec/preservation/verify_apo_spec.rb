describe Preservation::VerifyApo do
  let(:deposit_dir_pathname) { Pathname(File.join(File.dirname(__FILE__), '..', 'fixtures', 'deposit')) }
  let(:verify_apo) { described_class.new }

  describe 'relationshipMetadata.xml is in deposit bag' do
    describe 'but APO druid unattainable' do

      it 'raises ItemError if relationshipMetadata has no <isGovernedBy> element' do
        id = 'verify-apo-rel-md-no-isGovernedBy'
        deposit_bag_pathname = Pathname(File.join(deposit_dir_pathname, id))
        mock_moab = instance_double(Moab::StorageObject)
        allow(mock_moab).to receive(:deposit_bag_pathname).and_return(deposit_bag_pathname)
        allow(Stanford::StorageServices).to receive(:find_storage_object).and_return(mock_moab)
        exp_msg = "Unable to find isGovernedBy node of relationshipMetadata"
        expect { verify_apo.perform(id) }.to raise_error(Preservation::ItemError, exp_msg)
      end

      it 'raises ItemError if relationshipMetadata has no resource attribute for <isGovernedBy> element' do
        id = 'verify-apo-rel-md-no-resource-attr'
        deposit_bag_pathname = Pathname(File.join(deposit_dir_pathname, id))
        mock_moab = instance_double(Moab::StorageObject)
        allow(mock_moab).to receive(:deposit_bag_pathname).and_return(deposit_bag_pathname)
        allow(Stanford::StorageServices).to receive(:find_storage_object).and_return(mock_moab)
        exp_msg = "Unable to find 'resource' attribute for <isGovernedBy> in relationshipMetadata"
        expect { verify_apo.perform(id) }.to raise_error(Preservation::ItemError, exp_msg)
      end

      it 'raises ItemError if relationshipMetadata cannot be parsed' do
        id = 'verify-apo-rel-md-bad'
        deposit_bag_pathname = Pathname(File.join(deposit_dir_pathname, id))
        mock_moab = instance_double(Moab::StorageObject)
        allow(mock_moab).to receive(:deposit_bag_pathname).and_return(deposit_bag_pathname)
        allow(Stanford::StorageServices).to receive(:find_storage_object).and_return(mock_moab)
        rel_md_pathname = deposit_bag_pathname.join('data/metadata/relationshipMetadata.xml')
        exp_msg = "^Unable to parse #{rel_md_pathname}: .*"
        expect { verify_apo.perform(id) }.to raise_error(Preservation::ItemError, a_string_matching(exp_msg))
      end
    end

    describe 'and APO druid attained' do
      let(:id) { 'verify-apo-has-rel-md-v1' }
      let(:deposit_bag_pathname) { Pathname(File.join(deposit_dir_pathname, id)) }

      it "if the APO Moab's object_pathname is a directory then no errors are raised" do
        mock_moab = instance_double(Moab::StorageObject)
        allow(mock_moab).to receive(:deposit_bag_pathname).and_return(deposit_bag_pathname)
        mock_pathname = instance_double(Pathname)
        allow(mock_moab).to receive(:object_pathname).and_return(mock_pathname)
        allow(Stanford::StorageServices).to receive(:find_storage_object).and_return(mock_moab)
        expect(mock_pathname).to receive(:directory?).and_return(true)
        expect { verify_apo.perform(id) }.not_to raise_error
      end

      it "raises ItemError if the APO Moab's object_pathname is not a directory" do
        mock_moab = instance_double(Moab::StorageObject)
        allow(mock_moab).to receive(:deposit_bag_pathname).and_return(deposit_bag_pathname)
        mock_pathname = instance_double(Pathname)
        allow(mock_moab).to receive(:object_pathname).and_return(mock_pathname)
        allow(Stanford::StorageServices).to receive(:find_storage_object).and_return(mock_moab)
        expect(mock_pathname).to receive(:directory?).and_return(false)
        exp_msg = "Governing APO object druid:aa000aa0000 not found"
        expect { verify_apo.perform(id) }.to raise_error(Preservation::ItemError, exp_msg)
      end

      it "raises ItemError if the APO Moab's object_pathname is nil" do
        mock_moab = instance_double(Moab::StorageObject)
        allow(mock_moab).to receive(:deposit_bag_pathname).and_return(deposit_bag_pathname)
        allow(mock_moab).to receive(:object_pathname)
        allow(Stanford::StorageServices).to receive(:find_storage_object).and_return(mock_moab)
        exp_msg = "Governing APO object druid:aa000aa0000 not found"
        expect { verify_apo.perform(id) }.to raise_error(Preservation::ItemError, exp_msg)
      end
    end
  end

  describe 'relationshipMetadata.xml is NOT in deposit bag' do
    it 'logs a debug message that test is skipped if deposit version > 1' do
      id = 'verify-apo-no-rel-md-v2'
      deposit_bag_pathname = Pathname(File.join(deposit_dir_pathname, id))
      mock_moab = instance_double(Moab::StorageObject)
      allow(mock_moab).to receive(:deposit_bag_pathname).and_return(deposit_bag_pathname)
      allow(Stanford::StorageServices).to receive(:find_storage_object).and_return(mock_moab)
      exp_msg = "APO verification skipped: deposit version > 1 && no relationshipMetadata.xml in bag"
      allow(LyberCore::Log).to receive(:debug)
      verify_apo.perform(id)
      expect(LyberCore::Log).to have_received(:debug).with(exp_msg)
    end
    it 'raises ItemError if deposit version = 1' do
      id = 'verify-apo-no-rel-md-v1'
      deposit_bag_pathname = Pathname(File.join(deposit_dir_pathname, id))
      mock_moab = instance_double(Moab::StorageObject)
      allow(mock_moab).to receive(:deposit_bag_pathname).and_return(deposit_bag_pathname)
      allow(Stanford::StorageServices).to receive(:find_storage_object).and_return(mock_moab)
      exp_msg = "relationshipMetadata.xml not found in deposit bag"
      expect { verify_apo.perform(id) }.to raise_error(Preservation::ItemError, exp_msg)
    end
    it 'raises ItemError if deposit version is unavailable' do
      id = 'verify-apo-no-rel-md-no-version'
      deposit_bag_pathname = Pathname(File.join(deposit_dir_pathname, id))
      mock_moab = instance_double(Moab::StorageObject)
      allow(mock_moab).to receive(:deposit_bag_pathname).and_return(deposit_bag_pathname)
      allow(Stanford::StorageServices).to receive(:find_storage_object).and_return(mock_moab)
      exp_msg = "Unable to determine deposit version"
      expect { verify_apo.perform(id) }.to raise_error(Preservation::ItemError, exp_msg)
    end
  end
end
