module LinkedData
  module Models
    class SemanticArtefactCatalogRecord < LinkedData::Models::Base
      include LinkedData::Concerns::SemanticArtefact::AttributeMapping
      include LinkedData::Concerns::SemanticArtefact::AttributeFetcher

      model :SemanticArtefactCatalogRecord, namespace: :mod, name_with: ->(r) { record_id_generator(r) }
      
      # SAD attrs that map with submission
      attribute_mapped :recordId, namespace: :mod, mapped_to: { model: :ontology, attribute: :acronym}
      attribute_mapped :homepage, namespace: :foaf, mapped_to: { model: :ontology_submission }
      attribute_mapped :created, namespace: :dcterms, mapped_to: { model: :ontology_submission, attribute: :released }
      attribute_mapped :modified, namespace: :dcterms, mapped_to: { model: :ontology_submission, attribute: :modificationDate }
      attribute_mapped :curatedOn, namespace: :pav, mapped_to: { model: :ontology_submission }
      attribute_mapped :curatedBy, namespace: :pav, mapped_to: { model: :ontology_submission }
      attribute_mapped :dateSubmitted, namespace: :dcterms, mapped_to: { model: :ontology_submission, attribute: :creationDate }

      attribute :ontology, type: :ontology, enforce: [:existence]
      attribute :submission, type: :ontology_submission
      

      # Access control
      read_restriction_based_on ->(record) { record.ontology }

      serialize_default :recordId, :homepage, :created, :modified, :curatedOn, :curatedBy, :dateSubmitted
      
      
      def self.record_id_generator(record)
        record.ontology.bring(:acronym) if !record.ontology.loaded_attributes.include?(:acronym)
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
          sacr.recordId = ont.acronym
        end
      end
      
      def self.all(attributes, page, pagesize)
        all_count = Ontology.where.count
        onts = Ontology.where.include(:viewingRestriction, :administeredBy, :acl).page(page, pagesize).page_count_set(all_count).all
        all_records = onts.map do |o|
          new.tap do |sacr|
            sacr.ontology = o
            sacr.bring(*attributes) if attributes
          end
        end
        Goo::Base::Page.new(page, pagesize, all_count, all_records)
      end
      
      ##
      ## find all records of one artefact
      ## these are mapped to the submissions of an ontology
      def artefact_all_records(attributes)
        @ontology.bring(:submissions) unless @ontology.loaded_attributes.include?(:submissions)
        all_records = @ontology.submissions.map do |s|
          SemanticArtefactCatalogRecord.new.tap do |sacr|  
            sacr.ontology = @ontology
            sacr.submission = s
            sacr.bring(*attributes) if attributes
          end
        end
        all_records
      end
    end

  end
end
