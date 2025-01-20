module LinkedData
    module Models

        class SemanticArtefactDistribution < LinkedData::Models::Base
            
            class << self
                attr_accessor :attribute_mappings
                def attribute_mapped(name, **options)
                  mapped_to = options.delete(:mapped_to)
                  attribute(name, **options)
                  @attribute_mappings ||= {}
                  @attribute_mappings[name] = mapped_to if mapped_to
                end
            end

            model :SemanticArtefactDistribution, namespace: :mod, name_with: ->(s) { distribution_id_generator(s) }
            
            # SAD attrs that map with submission
            attribute_mapped :distributionId, mapped_to: { model: :ontology_submission, attribute: :submissionId }
            attribute_mapped :title, namespace: :dcterms, mapped_to: { model: :ontology_submission, attribute: :URI }
            attribute_mapped :deprecated, namespace: :owl, mapped_to: { model: :ontology_submission, attribute: :deprecated }
            attribute_mapped :hasRepresentationLanguage, namespace: :mod, mapped_to: { model: :ontology_submission, attribute: :hasOntologyLanguage }
            attribute_mapped :hasFormalityLevel, namespace: :mod, mapped_to: { model: :ontology_submission, attribute: :hasFormalityLevel }
            attribute_mapped :hasSyntax, namespace: :mod, mapped_to: { model: :ontology_submission, attribute: :hasOntologySyntax }
            attribute_mapped :useGuidelines, namespace: :cc, mapped_to: { model: :ontology_submission, attribute: :useGuidelines }
            attribute_mapped :description, namespace: :dcterms, mapped_to: { model: :ontology_submission, attribute: :description }
            attribute_mapped :created, namespace: :dcterms, mapped_to: { model: :ontology_submission, attribute: :released }
            attribute_mapped :modified, namespace: :dcterms, mapped_to: { model: :ontology_submission, attribute: :modificationDate }
            attribute_mapped :valid, namespace: :dcterms, mapped_to: { model: :ontology_submission, attribute: :valid }
            attribute_mapped :curatedOn, namespace: :pav, mapped_to: { model: :ontology_submission, attribute: :curatedOn }
            attribute_mapped :dateSubmitted, namespace: :dcterms, mapped_to: { model: :ontology_submission, attribute: :creationDate }
            attribute_mapped :conformsToKnowledgeRepresentationParadigm, namespace: :mod, mapped_to: { model: :ontology_submission, attribute: :conformsToKnowledgeRepresentationParadigm }
            attribute_mapped :usedEngineeringMethodology, namespace: :mod, mapped_to: { model: :ontology_submission, attribute: :usedOntologyEngineeringMethodology }
            attribute_mapped :prefLabelProperty, namespace: :mod, mapped_to: { model: :ontology_submission, attribute: :prefLabelProperty }
            attribute_mapped :synonymProperty, namespace: :mod, mapped_to: { model: :ontology_submission, attribute: :synonymProperty }
            attribute_mapped :definitionProperty, namespace: :mod, mapped_to: { model: :ontology_submission, attribute: :definitionProperty }
            attribute_mapped :authorProperty, namespace: :mod, mapped_to: { model: :ontology_submission, attribute: :authorProperty }
            attribute_mapped :obsoleteProperty, namespace: :mod, mapped_to: { model: :ontology_submission, attribute: :obsoleteProperty }
            attribute_mapped :createdProperty, namespace: :mod, mapped_to: { model: :ontology_submission, attribute: :createdProperty }
            attribute_mapped :modifiedProperty, namespace: :mod, mapped_to: { model: :ontology_submission, attribute: :modifiedProperty }
            attribute_mapped :hierarchyProperty, namespace: :mod, mapped_to: { model: :ontology_submission, attribute: :hierarchyProperty }
            attribute_mapped :accessURL, namespace: :dcat, mapped_to: { model: :ontology_submission, attribute: :pullLocation }
            attribute_mapped :downloadURL, namespace: :dcat, mapped_to: { model: :ontology_submission, attribute: :dataDump }
            attribute_mapped :endpoint, namespace: :sd, mapped_to: { model: :ontology_submission, attribute: :endpoint }
            attribute_mapped :imports, namespace: :owl, mapped_to: { model: :ontology_submission, attribute: :useImports }
            attribute_mapped :obsoleteParent, namespace: :mod, mapped_to: { model: :ontology_submission, attribute: :obsoleteParent }
            attribute_mapped :metadataVoc, namespace: :mod, mapped_to: { model: :ontology_submission, attribute: :metadataVoc }
            attribute_mapped :metrics, namespace: :mod, mapped_to: { model: :ontology_submission, attribute: :metrics }
            attribute_mapped :numberOfClasses, namespace: :mod, mapped_to: { model: :ontology_submission, attribute: :class_count }

            # SAD attrs that map with metrics
            attribute_mapped :numberOfAxioms, namespace: :mod, mapped_to: { model: :metric, attribute: :numberOfAxioms }
            attribute_mapped :maxDepth, namespace: :mod, mapped_to: { model: :metric, attribute: :maxDepth }
            attribute_mapped :maxChildCount, namespace: :mod, mapped_to: { model: :metric, attribute: :maxChildCount }
            attribute_mapped :averageChildCount, namespace: :mod, mapped_to: { model: :metric, attribute: :averageChildCount }
            attribute_mapped :classesWithOneChild, namespace: :mod, mapped_to: { model: :metric, attribute: :classesWithOneChild }
            attribute_mapped :classesWithMoreThan25Children, namespace: :mod, mapped_to: { model: :metric, attribute: :classesWithMoreThan25Children }
            attribute_mapped :classesWithNoDefinition, namespace: :mod, mapped_to: { model: :metric, attribute: :classesWithNoDefinition }


            # Attr special to SemanticArtefactDistribution
            attribute :submission, type: :ontology_submission
            
            serialize_default :distributionId, :title, :deprecated, :hasRepresentationLanguage, :hasSyntax, :description, :created
            serialize_never :submission


            def self.distribution_id_generator(ss)
                ss.submission.ontology.bring(:acronym) if !ss.submission.ontology.loaded_attributes.include?(:acronym)
                raise ArgumentError, "Acronym is nil to generate id" if ss.submission.ontology.acronym.nil?
                return RDF::URI.new(
                  "#{(Goo.id_prefix)}artefacts/#{CGI.escape(ss.submission.ontology.acronym.to_s)}/distributions/#{ss.submission.submissionId.to_s}"
                )
            end


            def initialize(sub)
                super()
                @submission = sub
                @submission.bring(*[:submissionId, :ontology=>[:acronym]])
                @distributionId = sub.submissionId
            end

            def self.type_uri
                self.namespace[self.model_name].to_s
            end

            # Method to fetch specific attributes and populate the SemanticArtefact instance
            def bring(*attributes)
                attributes = [attributes] unless attributes.is_a?(Array)
                attributes.each do |attr|
                    mapping = self.class.attribute_mappings[attr]
                    next if mapping.nil?

                    model = mapping[:model]
                    mapped_attr = mapping[:attribute]
                    
                    case model
                    when :ontology_submission
                        @submission.bring(*mapped_attr)
                        self.send("#{attr}=", @submission.send(mapped_attr)) if @submission.respond_to?(mapped_attr)
                    when :metrics
                        next
                        # TO-DO
                    end
                end
            end

        end

    end
end
  