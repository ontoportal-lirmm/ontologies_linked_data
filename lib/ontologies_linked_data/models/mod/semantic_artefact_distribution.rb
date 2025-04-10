module LinkedData
    module Models

        class SemanticArtefactDistribution < LinkedData::Models::Base
            include LinkedData::Concerns::SemanticArtefact::AttributeMapping
            include LinkedData::Concerns::SemanticArtefact::AttributeFetcher

            model :SemanticArtefactDistribution, namespace: :mod, name_with: ->(s) { distribution_id_generator(s) }
            
            # SAD attrs that map with submission
            attribute_mapped :distributionId, mapped_to: { model: :ontology_submission, attribute: :submissionId }
            attribute_mapped :title, namespace: :dcterms, mapped_to: { model: :ontology, attribute: :name }
            attribute_mapped :deprecated, namespace: :owl, mapped_to: { model: :ontology_submission }
            attribute_mapped :hasRepresentationLanguage, namespace: :mod, mapped_to: { model: :ontology_submission, attribute: :hasOntologyLanguage }
            attribute_mapped :hasFormalityLevel, namespace: :mod, mapped_to: { model: :ontology_submission }
            attribute_mapped :hasSyntax, namespace: :mod, mapped_to: { model: :ontology_submission, attribute: :hasOntologySyntax }
            attribute_mapped :useGuidelines, namespace: :cc, mapped_to: { model: :ontology_submission }
            attribute_mapped :description, namespace: :dcterms, mapped_to: { model: :ontology_submission }
            attribute_mapped :created, namespace: :dcterms, mapped_to: { model: :ontology_submission, attribute: :released }
            attribute_mapped :modified, namespace: :dcterms, mapped_to: { model: :ontology_submission, attribute: :modificationDate }
            attribute_mapped :valid, namespace: :dcterms, mapped_to: { model: :ontology_submission }
            attribute_mapped :curatedOn, namespace: :pav, mapped_to: { model: :ontology_submission }
            attribute_mapped :dateSubmitted, namespace: :dcterms, mapped_to: { model: :ontology_submission, attribute: :creationDate }
            attribute_mapped :conformsToKnowledgeRepresentationParadigm, namespace: :mod, mapped_to: { model: :ontology_submission }
            attribute_mapped :usedEngineeringMethodology, namespace: :mod, mapped_to: { model: :ontology_submission, attribute: :usedOntologyEngineeringMethodology }
            attribute_mapped :prefLabelProperty, namespace: :mod, mapped_to: { model: :ontology_submission }
            attribute_mapped :synonymProperty, namespace: :mod, mapped_to: { model: :ontology_submission }
            attribute_mapped :definitionProperty, namespace: :mod, mapped_to: { model: :ontology_submission }
            attribute_mapped :authorProperty, namespace: :mod, mapped_to: { model: :ontology_submission }
            attribute_mapped :obsoleteProperty, namespace: :mod, mapped_to: { model: :ontology_submission }
            attribute_mapped :createdProperty, namespace: :mod, mapped_to: { model: :ontology_submission }
            attribute_mapped :modifiedProperty, namespace: :mod, mapped_to: { model: :ontology_submission }
            attribute_mapped :hierarchyProperty, namespace: :mod, mapped_to: { model: :ontology_submission }
            attribute_mapped :accessURL, namespace: :dcat, mapped_to: { model: :ontology_submission, attribute: :pullLocation }
            attribute_mapped :downloadURL, namespace: :dcat, mapped_to: { model: :ontology_submission, attribute: :dataDump }
            attribute_mapped :endpoint, namespace: :sd, mapped_to: { model: :ontology_submission }
            attribute_mapped :imports, namespace: :owl, mapped_to: { model: :ontology_submission, attribute: :useImports }
            attribute_mapped :obsoleteParent, namespace: :mod, mapped_to: { model: :ontology_submission }
            attribute_mapped :metadataVoc, namespace: :mod, mapped_to: { model: :ontology_submission }
            attribute_mapped :metrics, namespace: :mod, mapped_to: { model: :ontology_submission }

            # SAD attrs that map with metrics
            attribute_mapped :numberOfClasses, namespace: :mod, mapped_to: { model: :metric, attribute: :classes }
            attribute_mapped :numberOfAxioms, namespace: :mod, mapped_to: { model: :metric }
            attribute_mapped :maxDepth, namespace: :mod, mapped_to: { model: :metric }
            attribute_mapped :maxChildCount, namespace: :mod, mapped_to: { model: :metric }
            attribute_mapped :averageChildCount, namespace: :mod, mapped_to: { model: :metric }
            attribute_mapped :classesWithOneChild, namespace: :mod, mapped_to: { model: :metric }
            attribute_mapped :classesWithMoreThan25Children, namespace: :mod, mapped_to: { model: :metric }
            attribute_mapped :classesWithNoDefinition, namespace: :mod, mapped_to: { model: :metric }
            attribute_mapped :numberOfIndividuals, namespace: :mod, enforce: [:integer],  mapped_to: { model: :metric, attribute: :individuals}
            attribute_mapped :numberOfProperties, namespace: :mod, enforce: [:integer],  mapped_to: { model: :metric, attribute: :properties}
            attribute_mapped :numberOfAgents, namespace: :mod, enforce: [:integer],  mapped_to: { model: :metric }
            attribute_mapped :numberOfObjectProperties, namespace: :mod, enforce: [:integer],  mapped_to: { model: :metric}
            attribute_mapped :numberOfDataProperties, namespace: :mod, enforce: [:integer],  mapped_to: { model: :metric}
            attribute_mapped :numberOfLabels, namespace: :mod, enforce: [:integer],  mapped_to: { model: :metric }
            attribute_mapped :numberOfDeprecated, namespace: :mod, enforce: [:integer],  mapped_to: { model: :metric }
            attribute_mapped :classesWithNoFormalDefinition, namespace: :mod, mapped_to: { model: :metric }
            attribute_mapped :classesWithNoLabel, namespace: :mod, enforce: [:integer],  mapped_to: { model: :metric }
            attribute_mapped :classesWithNoAuthorMetadata, namespace: :mod, enforce: [:integer],  mapped_to: { model: :metric }
            attribute_mapped :classesWithNoDateMetadata, namespace: :mod, enforce: [:integer],  mapped_to: { model: :metric }
            attribute_mapped :numberOfMappings, namespace: :mod, enforce: [:integer],  mapped_to: { model: :metric }
            
            # Attr special to SemanticArtefactDistribution
            attribute :ontology, type: :ontology
            attribute :submission, type: :ontology_submission

            # Access control
            read_restriction_based_on ->(artefct_distribution) { artefct_distribution.submission.ontology }
            
            serialize_default :distributionId, :title, :hasRepresentationLanguage, :hasSyntax, :description, :created, :modified, 
                              :conformsToKnowledgeRepresentationParadigm, :usedEngineeringMethodology, :prefLabelProperty, 
                              :synonymProperty, :definitionProperty, :accessURL, :downloadURL

            serialize_never :submission


            def self.distribution_id_generator(ss)
                ss.submission.ontology.bring(:acronym) if !ss.submission.ontology.loaded_attributes.include?(:acronym)
                raise ArgumentError, "Acronym is nil to generate id" if ss.submission.ontology.acronym.nil?
                return RDF::URI.new(
                  "#{(Goo.id_prefix)}artefacts/#{CGI.escape(ss.ontology.acronym.to_s)}/distributions/#{ss.submission.submissionId.to_s}"
                )
            end


            def initialize(sub)
                super()
                @submission = sub
                @submission.bring(*[:submissionId, :ontology=>[:acronym, :administeredBy, :acl, :viewingRestriction]])
                @distributionId = sub.submissionId
                @ontology = @submission.ontology
            end


        end

    end
end
  