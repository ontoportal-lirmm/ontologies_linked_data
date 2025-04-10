module LinkedData
  module Models
    class SemanticArtefactCatalogRecord < LinkedData::Models::Base
      include LinkedData::Concerns::SemanticArtefact::AttributeMapping
      include LinkedData::Concerns::SemanticArtefact::AttributeFetcher

      model :SemanticArtefactCatalogRecord, namespace: :mod, name_with: ->(r) { record_id_generator(r) }

      # mod specs attributes
      attribute_mapped :acronym, namespace: :omv, mapped_to: { model: :ontology }
      attribute_mapped :relatedArtefactId, mapped_to: { model: self }, default: ->(r) {  RDF::URI("#{(Goo.id_prefix)}artefacts/#{CGI.escape(r.ontology.acronym.to_s)}") }
      attribute_mapped :homepage, namespace: :foaf, mapped_to: { model: self },  default: ->(r) { RDF::URI("http://#{LinkedData.settings.ui_host}/#{r.ontology.acronym}") } #handler: :record_home_page
      attribute_mapped :created, namespace: :dcterms, mapped_to: { model: self }, handler: :get_creation_date
      attribute_mapped :modified, namespace: :dcterms, mapped_to: { model: self }, handler: :get_modification_date
      attribute_mapped :curatedOn, namespace: :pav, mapped_to: { model: :ontology_submission }
      attribute_mapped :curatedBy, namespace: :pav, mapped_to: { model: :ontology_submission }

      # additional attributes
      attribute_mapped :viewingRestriction, mapped_to: { model: :ontology }
      attribute_mapped :administeredBy, mapped_to: { model: :ontology }
      attribute_mapped :doNotUpdate, mapped_to: { model: :ontology }
      attribute_mapped :flat, mapped_to: { model: :ontology }
      attribute_mapped :summaryOnly, mapped_to: { model: :ontology }
      attribute_mapped :acl, mapped_to: { model: :ontology }
      attribute_mapped :ontologyType, mapped_to: { model: :ontology }
      attribute_mapped :classType, mapped_to: { model: :ontology_submission }
      attribute_mapped :missingImports, mapped_to: { model: :ontology_submission }
      attribute_mapped :submissionStatus, mapped_to: { model: :ontology_submission }
      attribute_mapped :pullLocation, mapped_to: { model: :ontology_submission }
      attribute_mapped :dataDump, namespace: :void, mapped_to: { model: :ontology_submission }
      attribute_mapped :csvDump, mapped_to: { model: :ontology_submission }
      attribute_mapped :uploadFilePath, mapped_to: { model: :ontology_submission }
      attribute_mapped :diffFilePath, mapped_to: { model: :ontology_submission }
      attribute_mapped :masterFileName, mapped_to: { model: :ontology_submission }


      attribute :ontology, type: :ontology, enforce: [:existence]
      attribute :submission, type: :ontology_submission

      # Access control
      read_restriction_based_on ->(record) { record.ontology }

      serialize_default :acronym, :relatedArtefactId, :homepage, :created, :modified, :curatedOn, :curatedBy
      serialize_never :ontology, :submission

      def self.record_id_generator(record)
        record.ontology.bring(:acronym) if record.ontology.bring?(:acronym)
        raise ArgumentError, "Acronym is nil for ontology  #{record.ontology.id} to generate id" if record.ontology.acronym.nil?
        return RDF::URI.new(
          "#{(Goo.id_prefix)}records/#{CGI.escape(record.ontology.acronym.to_s)}"
        )
      end

      ##
      ## find an artefact (ontology) and map it to record
      def self.find(artefact_id)
        ont = Ontology.find(artefact_id).include(:acronym, :viewingRestriction, :administeredBy, :acl).first
        return nil unless ont
        new.tap do |sacr|
          sacr.ontology = ont
        end
      end
      
      def self.all(attributes, page, pagesize)
        all_count = Ontology.where.count
        onts = Ontology.where.include(:acronym, :viewingRestriction, :administeredBy, :acl).page(page, pagesize).page_count_set(all_count).all
        all_records = onts.map do |o|
          new.tap do |sacr|
            sacr.ontology = o
            sacr.bring(*attributes) if attributes
          end
        end
        Goo::Base::Page.new(page, pagesize, all_count, all_records)
      end
      
      private
      def get_modification_date
        fetch_submission_date(:max_by)
      end
      
      def get_creation_date
        fetch_submission_date(:min_by)
      end
      
      def fetch_submission_date(method)
        @ontology.bring(submissions: [:submissionId, :creationDate]) if @ontology.bring?(:submissions)
        submission = @ontology.submissions.public_send(method, &:submissionId)
        return unless submission
      
        submission.bring(:creationDate) unless submission.bring?(:creationDate)
        submission.creationDate
      end


    end
  end
end
