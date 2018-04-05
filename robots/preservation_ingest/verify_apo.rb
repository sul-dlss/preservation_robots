# Robot package to run under multiplexing infrastructure
module Robots
  # Use DorRepo/SdrRepo to match the workflow repo (and avoid name collision with Dor module)
  module SdrRepo
    # The workflow package name - match the actual workflow name, minus ending WF (using CamelCase)
    module PreservationIngest
      # Robot verifies THIS object's governing APO exists as its own Moab.
      #   We sensibly only check the APO if relationshipMetadata.xml is in
      #   THIS object's deposit bag || if deposit will be version 1 of THIS Moab.
      class VerifyApo < Base
        ROBOT_NAME = 'verify-apo'.freeze
        DATA_DIR = 'data'.freeze
        METADATA_DIR = 'metadata'.freeze
        RELATIONSHIP_MD_FNAME = 'relationshipMetadata.xml'.freeze
        VERSION_MD_FNAME = 'versionMetadata.xml'.freeze

        def initialize(opts = {})
          super(REPOSITORY, WORKFLOW_NAME, ROBOT_NAME, opts)
        end

        def perform(druid)
          @druid = druid # for base class attr_accessor
          verify_governing_apo
        end

        private

        def verify_governing_apo
          LyberCore::Log.debug("#{ROBOT_NAME} #{druid} starting")
          if relationship_md_pathname
            verify_apo_moab
            LyberCore::Log.debug("APO #{apo_druid} was verified")
          else
            raise(ItemError, "relationshipMetadata.xml not found in deposit bag") unless deposit_version > 1
            LyberCore::Log.debug("APO verification skipped: deposit version > 1 && no relationshipMetadata.xml in bag")
          end
        end

        def relationship_md_pathname
          @relationship_md_pathname ||= deposit_bag_pathname.join(DATA_DIR, METADATA_DIR, RELATIONSHIP_MD_FNAME)
          @relationship_md_pathname if @relationship_md_pathname.file?
        end

        def verify_apo_moab
          apo_moab = Stanford::StorageServices.find_storage_object(apo_druid)
          return if apo_moab && apo_moab.object_pathname && apo_moab.object_pathname.directory?
          raise(ItemError, "Governing APO object #{apo_druid} not found")
        end

        def apo_druid
          rel_md_ng_xml = Nokogiri::XML(File.open(relationship_md_pathname.to_s), &:strict)
          nodeset = rel_md_ng_xml.xpath("//hydra:isGovernedBy", 'hydra' => 'http://projecthydra.org/ns/relations#')
          raise(ItemError, "Unable to find isGovernedBy node of relationshipMetadata") if nodeset.empty?

          apo_attr = nodeset.first.attribute_with_ns('resource', 'http://www.w3.org/1999/02/22-rdf-syntax-ns#')
          err_msg = "Unable to find 'resource' attribute for <isGovernedBy> in relationshipMetadata"
          raise(ItemError, err_msg) unless apo_attr
          apo_attr.text.split('/')[-1]
        rescue Nokogiri::XML::SyntaxError => e
          raise(ItemError, "Unable to parse #{relationship_md_pathname}: #{e.message}")
        end

        # NOTE : if there is an XML parsing error, deposit_version is nil and
        #   we raise error in caller (verify_governing_apo)
        def deposit_version
          version_md_pathname = deposit_bag_pathname.join(DATA_DIR, METADATA_DIR, VERSION_MD_FNAME)
          version_md_ng_xml = Nokogiri::XML(version_md_pathname.read)
          nodeset = version_md_ng_xml.xpath("/versionMetadata/version")
          # note: version id _should_ have been successfully retrieved for success in previous validate-bag robot
          raise(ItemError, "Unable to determine deposit version") if nodeset.empty?
          nodeset.last['versionId'].to_i
        end
      end
    end
  end
end
