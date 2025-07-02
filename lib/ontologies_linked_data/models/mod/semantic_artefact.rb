require 'ontologies_linked_data/models/mod/semantic_artefact_distribution'
require 'ontologies_linked_data/models/mod/semantic_artefact_catalog_record'
require 'ontologies_linked_data/models/skos/scheme'
require 'ontologies_linked_data/models/skos/collection'
require 'ontologies_linked_data/models/skos/skosxl'


module LinkedData
    module Models

        class SemanticArtefact < LinkedData::Models::ModBase
            include LinkedData::Concerns::SemanticArtefact::AttributeMapping
            include LinkedData::Concerns::SemanticArtefact::AttributeFetcher

            model :SemanticArtefact, namespace: :mod, name_with: ->(s) { artefact_id_generator(s) }
            
            # # SemanticArtefact attrs that map with ontology
            attribute_mapped :acronym, namespace: :mod, mapped_to: { model: :ontology }
            attribute_mapped :title, namespace: :dcterms, mapped_to: { model: :ontology, attribute: :name }
            attribute_mapped :accessRights, namespace: :dcterms , mapped_to: { model: :ontology, attribute: :viewingRestriction }
            attribute_mapped :hasEvaluation, namespace: :mod, mapped_to: { model: :ontology, attribute: :reviews }
            attribute_mapped :group, namespace: :mod, mapped_to: { model: :ontology }
            attribute_mapped :subject, namespace: :dcterms, mapped_to: { model: :ontology, attribute: :hasDomain }
            attribute_mapped :usedInProject, namespace: :mod, mapped_to: { model: :ontology, attribute: :projects }
            attribute_mapped :isPartOf, namespace: :dcterms, mapped_to:{ model: :ontology, attribute: :viewOf}
            attribute_mapped :propertyPartition, namespace: :void, mapped_to:{ model: :ontology, attribute: :properties}
            attribute_mapped :hasVersion, namespace: :dcterms, mapped_to:{ model: :ontology, attribute: :submissions}

            # SemanticArtefact attrs that maps with submission
            attribute_mapped :URI, namespace: :mod, mapped_to: { model: :ontology_submission }
            attribute_mapped :versionIRI, namespace: :owl, mapped_to: { model: :ontology_submission }
            attribute_mapped :identifier, namespace: :dcterms, mapped_to: { model: :ontology_submission }
            attribute_mapped :creator, namespace: :dcterms, mapped_to: { model: :ontology_submission, attribute: :hasCreator }
            attribute_mapped :versionInfo, namespace: :owl, mapped_to: { model: :ontology_submission, attribute: :version}
            attribute_mapped :status, namespace: :mod, mapped_to: { model: :ontology_submission }
            attribute_mapped :deprecated, namespace: :owl, mapped_to: { model: :ontology_submission }
            attribute_mapped :language, namespace: :dcterms, mapped_to: { model: :ontology_submission, attribute: :naturalLanguage}
            attribute_mapped :type, namespace: :dcterms, mapped_to: { model: :ontology_submission, attribute: :isOfType}
            attribute_mapped :license, namespace: :dcterms, mapped_to: { model: :ontology_submission, attribute: :hasLicense}
            attribute_mapped :useGuidelines, namespace: :cc, mapped_to: { model: :ontology_submission }
            attribute_mapped :morePermissions, namespace: :cc, mapped_to: { model: :ontology_submission }
            attribute_mapped :rightsHolder, namespace: :dcterms, mapped_to: { model: :ontology_submission, attribute: :copyrightHolder}
            attribute_mapped :description, namespace: :dcterms, mapped_to: { model: :ontology_submission }
            attribute_mapped :homepage, namespace: :foaf, mapped_to: { model: :ontology_submission }
            attribute_mapped :landingPage, namespace: :dcat, mapped_to: { model: :ontology_submission, attribute: :documentation}
            attribute_mapped :comment, namespace: :rdfs, mapped_to: { model: :ontology_submission, attribute: :notes}
            attribute_mapped :keyword, namespace: :dcat, mapped_to: { model: :ontology_submission, attribute: :keywords}
            attribute_mapped :alternative, namespace: :dcterms, mapped_to: { model: :ontology_submission }
            attribute_mapped :hiddenLabel, namespace: :skos, mapped_to: { model: :ontology_submission }
            attribute_mapped :abstract, namespace: :dcterms, mapped_to: { model: :ontology_submission }
            attribute_mapped :bibliographicCitation, namespace: :dcterms, mapped_to: { model: :ontology_submission, attribute: :publication}
            attribute_mapped :contactPoint, namespace: :dcat, mapped_to: { model: :ontology_submission, attribute: :contact}
            attribute_mapped :contributor, namespace: :dcterms, mapped_to: { model: :ontology_submission, attribute: :hasContributor}
            attribute_mapped :curatedBy, namespace: :pav, mapped_to: { model: :ontology_submission }
            attribute_mapped :translator, namespace: :schema, mapped_to: { model: :ontology_submission }
            attribute_mapped :publisher, namespace: :dcterms, mapped_to: { model: :ontology_submission }
            attribute_mapped :fundedBy, namespace: :foaf, mapped_to: { model: :ontology_submission }
            attribute_mapped :endorsedBy, namespace: :mod, mapped_to: { model: :ontology_submission }
            attribute_mapped :comment, namespace: :schema, mapped_to: { model: :ontology_submission, attribute: :notes}
            attribute_mapped :audience, namespace: :dcterms, mapped_to: { model: :ontology_submission }
            attribute_mapped :repository, namespace: :doap, mapped_to: { model: :ontology_submission }
            attribute_mapped :bugDatabase, namespace: :doap, mapped_to: { model: :ontology_submission }
            attribute_mapped :mailingList, namespace: :doap, mapped_to: { model: :ontology_submission }
            attribute_mapped :toDoList, namespace: :mod, mapped_to: { model: :ontology_submission }
            attribute_mapped :award, namespace: :schema, mapped_to: { model: :ontology_submission }
            attribute_mapped :knownUsage, namespace: :mod, mapped_to: { model: :ontology_submission }
            attribute_mapped :designedForTask, namespace: :mod, mapped_to: { model: :ontology_submission, attribute: :designedForOntologyTask}
            attribute_mapped :coverage, namespace: :dcterms, mapped_to: { model: :ontology_submission }
            attribute_mapped :example, namespace: :vann, mapped_to: { model: :ontology_submission }
            attribute_mapped :createdWith, namespace: :pav, mapped_to: { model: :ontology_submission, attribute: :usedOntologyEngineeringTool}
            attribute_mapped :accrualMethod, namespace: :dcterms, mapped_to: { model: :ontology_submission }
            attribute_mapped :accrualPeriodicity, namespace: :dcterms, mapped_to: { model: :ontology_submission }
            attribute_mapped :accrualPolicy, namespace: :dcterms, mapped_to: { model: :ontology_submission }
            attribute_mapped :competencyQuestion, namespace: :mod, mapped_to: { model: :ontology_submission }
            attribute_mapped :wasGeneratedBy, namespace: :prov, mapped_to: { model: :ontology_submission }
            attribute_mapped :wasInvalidatedBy, namespace: :prov, mapped_to: { model: :ontology_submission }
            attribute_mapped :isFormatOf, namespace: :dcterms, mapped_to: { model: :ontology_submission }
            attribute_mapped :hasFormat, namespace: :dcterms, mapped_to: { model: :ontology_submission }
            attribute_mapped :uriLookupEndpoint, namespace: :void, mapped_to: { model: :ontology_submission }
            attribute_mapped :openSearchDescription, namespace: :void, mapped_to: { model: :ontology_submission }
            attribute_mapped :source, namespace: :dcterms, mapped_to: { model: :ontology_submission }
            attribute_mapped :includedInDataCatalog, namespace: :schema, mapped_to: { model: :ontology_submission }
            attribute_mapped :priorVersion, namespace: :owl, mapped_to: { model: :ontology_submission, attribute: :hasPriorVersion}
            attribute_mapped :hasPart, namespace: :dcterms, mapped_to: { model: :ontology_submission }
            attribute_mapped :relation, namespace: :dcterms, mapped_to: { model: :ontology_submission, attribute: :ontologyRelatedTo}
            attribute_mapped :semanticArtefactRelation, namespace: :mod, mapped_to: { model: :ontology_submission, attribute: :ontologyRelatedTo}
            attribute_mapped :specializes, namespace: :mod, mapped_to: { model: :ontology_submission, attribute: :explanationEvolution}
            attribute_mapped :generalizes, namespace: :mod, mapped_to: { model: :ontology_submission }
            attribute_mapped :usedBy, namespace: :mod, mapped_to: { model: :ontology_submission }
            attribute_mapped :reliesOn, namespace: :mod, mapped_to: { model: :ontology_submission, attribute: :ontologyRelatedTo}
            attribute_mapped :similar, namespace: :mod, mapped_to: { model: :ontology_submission, attribute: :similarTo}
            attribute_mapped :comesFromTheSameDomain, namespace: :mod, mapped_to: { model: :ontology_submission }
            attribute_mapped :hasEquivalencesWith, namespace: :mod, mapped_to: { model: :ontology_submission, attribute: :isAlignedTo}
            attribute_mapped :backwardCompatibleWith, namespace: :owl, mapped_to: { model: :ontology_submission, attribute: :isBackwardCompatibleWith}
            attribute_mapped :incompatibleWith, namespace: :owl, mapped_to: { model: :ontology_submission, attribute: :isIncompatibleWith}
            attribute_mapped :hasDisparateModellingWith, namespace: :mod, mapped_to: { model: :ontology_submission, attribute: :hasDisparateModelling}
            attribute_mapped :hasDisjunctionsWith, namespace: :mod, mapped_to: { model: :ontology_submission }
            attribute_mapped :workTranslation, namespace: :schema, mapped_to: { model: :ontology_submission }
            attribute_mapped :translationOfWork, namespace: :schema, mapped_to: { model: :ontology_submission }
            attribute_mapped :uriRegexPattern, namespace: :void, mapped_to: { model: :ontology_submission }
            attribute_mapped :preferredNamespaceUri, namespace: :vann, mapped_to: { model: :ontology_submission }
            attribute_mapped :preferredNamespacePrefix, namespace: :vann, mapped_to: { model: :ontology_submission }
            attribute_mapped :exampleResource, namespace: :void, mapped_to: { model: :ontology_submission, attribute: :exampleIdentifier}
            attribute_mapped :primaryTopic, namespace: :foaf, mapped_to: { model: :ontology_submission, attribute: :keyClasses}
            attribute_mapped :rootResource, namespace: :void, mapped_to: { model: :ontology_submission, attribute: :roots}
            attribute_mapped :changes, namespace: :vann, mapped_to: { model: :ontology_submission, attribute: :diffFilePath}
            attribute_mapped :associatedMedia, namespace: :schema, mapped_to: { model: :ontology_submission }
            attribute_mapped :depiction, namespace: :foaf, mapped_to: { model: :ontology_submission }
            attribute_mapped :logo, namespace: :foaf, mapped_to: { model: :ontology_submission }
            attribute_mapped :metrics, namespace: :mod, mapped_to: { model: :ontology_submission }

            attribute_mapped :numberOfNotes, namespace: :mod, enforce: [:integer],  mapped_to: { model: :metric }
            attribute_mapped :numberOfUsingProjects, namespace: :mod, enforce: [:integer],  mapped_to: { model: :metric }
            attribute_mapped :numberOfEndorsements, namespace: :mod, enforce: [:integer],  mapped_to: { model: :metric }
            attribute_mapped :numberOfEvaluations, namespace: :mod, enforce: [:integer],  mapped_to: { model: :metric }
            attribute_mapped :numberOfUsers, namespace: :mod, enforce: [:integer],  mapped_to: { model: :metric }
            attribute_mapped :numberOfAgents, namespace: :mod, enforce: [:integer],  mapped_to: { model: :metric }

            attribute :ontology, type: :ontology, enforce: [:existence]
            
            links_load :acronym
            link_to LinkedData::Hypermedia::Link.new("distributions", lambda {|s| "mod-api/artefacts/#{s.acronym}/distributions"}, LinkedData::Models::SemanticArtefactDistribution.type_uri),
                    LinkedData::Hypermedia::Link.new("record", lambda {|s| "mod-api/artefacts/#{s.acronym}/record"}, LinkedData::Models::SemanticArtefactCatalogRecord.type_uri),
                    LinkedData::Hypermedia::Link.new("resources", lambda {|s| "mod-api/artefacts/#{s.acronym}/resources"}),
                    LinkedData::Hypermedia::Link.new("classes", lambda {|s| "mod-api/artefacts/#{s.acronym}/resources/classes"}, LinkedData::Models::Class.uri_type),
                    LinkedData::Hypermedia::Link.new("concepts", lambda {|s| "mod-api/artefacts/#{s.acronym}/resources/concepts"}, LinkedData::Models::Class.uri_type),
                    LinkedData::Hypermedia::Link.new("properties", lambda {|s| "mod-api/artefacts/#{s.acronym}/resources/properties"}, "#{Goo.namespaces[:metadata].to_s}Property"),
                    LinkedData::Hypermedia::Link.new("individuals", lambda {|s| "mod-api/artefacts/#{s.acronym}/resources/individuals"}, LinkedData::Models::Class.uri_type),
                    LinkedData::Hypermedia::Link.new("schemes", lambda {|s| "mod-api/artefacts/#{s.acronym}/resources/schemes"}, LinkedData::Models::SKOS::Scheme.uri_type),
                    LinkedData::Hypermedia::Link.new("collection", lambda {|s| "mod-api/artefacts/#{s.acronym}/resources/collections"}, LinkedData::Models::SKOS::Collection.uri_type),
                    LinkedData::Hypermedia::Link.new("labels", lambda {|s| "mod-api/artefacts/#{s.acronym}/resources/labels"}, LinkedData::Models::SKOS::Label.uri_type)

            # Access control
            read_restriction_based_on ->(artefct) { artefct.ontology }

            serialize_default :acronym, :title, :accessRights, :subject, :URI, :versionIRI, :creator, :identifier, :status, :language, 
                              :license, :rightsHolder, :description, :landingPage, :keyword, :bibliographicCitation, :contactPoint,
                              :contributor, :publisher, :coverage, :createdWith, :accrualMethod, :accrualPeriodicity, 
                              :competencyQuestion, :wasGeneratedBy, :hasFormat, :includedInDataCatalog, :semanticArtefactRelation

            serialize_never :ontology

            def self.artefact_id_generator(ss)
                ss.ontology.bring(:acronym) if !ss.ontology.loaded_attributes.include?(:acronym)
                raise ArgumentError, "Acronym is nil for ontology  #{ss.ontology.id} to generate id" if ss.ontology.acronym.nil?
                return RDF::URI.new(
                  "#{(Goo.id_prefix)}artefacts/#{CGI.escape(ss.ontology.acronym.to_s)}"
                )
            end

            def self.find(artefact_id)
                ont = Ontology.find(artefact_id).include(:acronym, :viewingRestriction, :administeredBy, :acl).first
                return nil unless ont

                new.tap do |sa|
                    sa.ontology = ont
                    sa.acronym = ont.acronym
                end
            end

            def self.all_artefacts(attributes, page, pagesize)
                all_count = Ontology.where.count
                onts = Ontology.where.include(:viewingRestriction, :administeredBy, :acl).page(page, pagesize).page_count_set(all_count).all
                all_artefacts = onts.map do |o|
                    new.tap do |sa|
                        sa.ontology = o
                        sa.bring(*attributes) if attributes
                    end
                end
                LinkedData::Models::HydraPage.new(page, pagesize, all_count, all_artefacts)
            end

            def latest_distribution(status)
                sub = @ontology.latest_submission(status)
                SemanticArtefactDistribution.new(sub) unless sub.nil?
            end

            def distribution(dist_id)
                sub = @ontology.submission(dist_id)
                SemanticArtefactDistribution.new(sub) unless sub.nil?
            end
        
            def all_distributions(attributes, page, pagesize)
                filter_by_acronym = Goo::Filter.new(ontology: [:acronym]) == @ontology.acronym
                submissions_count =  OntologySubmission.where.filter(filter_by_acronym).count
                submissions_page = OntologySubmission.where.include(:distributionId)
                                                    .filter(filter_by_acronym)
                                                    .page(page, pagesize)
                                                    .page_count_set(submissions_count)
                                                    .all
                all_distributions = submissions_page.map do |submission|
                    SemanticArtefactDistribution.new(submission).tap do |dist|
                        dist.bring(*attributes) if attributes
                    end
                end
                LinkedData::Models::HydraPage.new(page, pagesize, submissions_count, all_distributions)
            end
    
            def analytics
                @ontology.analytics
            end
            
        end
    end
end
