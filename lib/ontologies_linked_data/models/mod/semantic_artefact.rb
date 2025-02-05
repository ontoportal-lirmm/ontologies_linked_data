require 'ontologies_linked_data/models/mod/semantic_artefact_distribution'
require 'ontologies_linked_data/models/skos/scheme'
require 'ontologies_linked_data/models/skos/collection'
require 'ontologies_linked_data/models/skos/skosxl'


module LinkedData
    module Models

        class SemanticArtefact < LinkedData::Models::Base

            class << self
                attr_accessor :attribute_mappings
                def attribute_mapped(name, **options)
                  mapped_to = options.delete(:mapped_to)
                  attribute(name, **options)
                  @attribute_mappings ||= {}
                  @attribute_mappings[name] = mapped_to if mapped_to
                end
            end

            model :SemanticArtefact, namespace: :mod, name_with: ->(s) { artefact_id_generator(s) }
            
            # # SemanticArtefact attrs that map with ontology
            attribute_mapped :acronym, namespace: :mod, mapped_to: { model: :ontology, attribute: :acronym }
            attribute_mapped :title, namespace: :dcterms, mapped_to: { model: :ontology, attribute: :name }
            attribute_mapped :accessRights, namespace: :dcterms , mapped_to: { model: :ontology, attribute: :viewingRestriction }
            attribute_mapped :hasEvaluation, namespace: :mod, mapped_to: { model: :ontology, attribute: :reviews }
            attribute_mapped :group, namespace: :mod, mapped_to: { model: :ontology, attribute: :group }
            attribute_mapped :subject, namespace: :dcterms, mapped_to: { model: :ontology, attribute: :hasDomain }
            attribute_mapped :usedInProject, namespace: :mod, mapped_to: { model: :ontology, attribute: :projects }
            attribute_mapped :isPartOf, namespace: :dcterms, mapped_to:{model: :ontology, attribute: :viewOf}
            attribute_mapped :propertyPartition, namespace: :void, mapped_to:{model: :ontology, attribute: :properties}
            attribute_mapped :hasVersion, namespace: :dcterms, mapped_to:{model: :ontology, attribute: :submissions}

            # SemanticArtefact attrs that maps with submission
            attribute_mapped :URI, namespace: :mod, mapped_to: {model: :ontology_submission, attribute: :URI}
            attribute_mapped :versionIRI, namespace: :owl, mapped_to: {model: :ontology_submission, attribute: :versionIRI}
            attribute_mapped :identifier, namespace: :dcterms, mapped_to: {model: :ontology_submission, attribute: :identifier}
            attribute_mapped :creator, namespace: :dcterms, mapped_to: { model: :ontology_submission, attribute: :hasCreator }
            attribute_mapped :versionInfo, namespace: :owl, mapped_to: {model: :ontology_submission, attribute: :version}
            attribute_mapped :status, namespace: :mod, mapped_to: {model: :ontology_submission, attribute: :status}
            attribute_mapped :deprecated, namespace: :owl, mapped_to: {model: :ontology_submission, attribute: :deprecated}
            attribute_mapped :language, namespace: :dcterms, mapped_to: {model: :ontology_submission, attribute: :naturalLanguage}
            attribute_mapped :type, namespace: :dcterms, mapped_to: {model: :ontology_submission, attribute: :isOfType}
            attribute_mapped :license, namespace: :dcterms, mapped_to: {model: :ontology_submission, attribute: :hasLicense}
            attribute_mapped :useGuidelines, namespace: :cc, mapped_to: {model: :ontology_submission, attribute: :useGuidelines}
            attribute_mapped :morePermissions, namespace: :cc, mapped_to: {model: :ontology_submission, attribute: :morePermissions}
            attribute_mapped :rightsHolder, namespace: :dcterms, mapped_to: {model: :ontology_submission, attribute: :copyrightHolder}
            attribute_mapped :description, namespace: :dcterms, mapped_to: {model: :ontology_submission, attribute: :description}
            attribute_mapped :homepage, namespace: :foaf, mapped_to: {model: :ontology_submission, attribute: :homepage}
            attribute_mapped :landingPage, namespace: :dcat, mapped_to: {model: :ontology_submission, attribute: :documentation}
            attribute_mapped :comment, namespace: :rdfs, mapped_to: {model: :ontology_submission, attribute: :notes}
            attribute_mapped :keyword, namespace: :dcat, mapped_to: {model: :ontology_submission, attribute: :keywords}
            attribute_mapped :alternative, namespace: :dcterms, mapped_to: {model: :ontology_submission, attribute: :alternative}
            attribute_mapped :hiddenLabel, namespace: :skos, mapped_to: {model: :ontology_submission, attribute: :hiddenLabel}
            attribute_mapped :abstract, namespace: :dcterms, mapped_to: {model: :ontology_submission, attribute: :abstract}
            attribute_mapped :bibliographicCitation, namespace: :dcterms, mapped_to: {model: :ontology_submission, attribute: :publication}
            attribute_mapped :contactPoint, namespace: :dcat, mapped_to: {model: :ontology_submission, attribute: :contact}
            attribute_mapped :contributor, namespace: :dcterms, mapped_to: {model: :ontology_submission, attribute: :hasContributor}
            attribute_mapped :curatedBy, namespace: :pav, mapped_to: {model: :ontology_submission, attribute: :curatedBy}
            attribute_mapped :translator, namespace: :schema, mapped_to: {model: :ontology_submission, attribute: :translator}
            attribute_mapped :publisher, namespace: :dcterms, mapped_to: {model: :ontology_submission, attribute: :publisher}
            attribute_mapped :fundedBy, namespace: :foaf, mapped_to: {model: :ontology_submission, attribute: :fundedBy}
            attribute_mapped :endorsedBy, namespace: :mod, mapped_to: {model: :ontology_submission, attribute: :endorsedBy}
            attribute_mapped :comment, namespace: :schema, mapped_to: {model: :ontology_submission, attribute: :notes}
            attribute_mapped :audience, namespace: :dcterms, mapped_to: {model: :ontology_submission, attribute: :audience}
            attribute_mapped :repository, namespace: :doap, mapped_to: {model: :ontology_submission, attribute: :repository}
            attribute_mapped :bugDatabase, namespace: :doap, mapped_to: {model: :ontology_submission, attribute: :bugDatabase}
            attribute_mapped :mailingList, namespace: :doap, mapped_to: {model: :ontology_submission, attribute: :mailingList}
            attribute_mapped :toDoList, namespace: :mod, mapped_to: {model: :ontology_submission, attribute: :toDoList}
            attribute_mapped :award, namespace: :schema, mapped_to: {model: :ontology_submission, attribute: :award}
            attribute_mapped :knownUsage, namespace: :mod, mapped_to: {model: :ontology_submission, attribute: :knownUsage}
            attribute_mapped :designedForTask, namespace: :mod, mapped_to: {model: :ontology_submission, attribute: :designedForOntologyTask}
            attribute_mapped :coverage, namespace: :dcterms, mapped_to: {model: :ontology_submission, attribute: :coverage}
            attribute_mapped :example, namespace: :vann, mapped_to: {model: :ontology_submission, attribute: :example}
            attribute_mapped :createdWith, namespace: :pav, mapped_to: {model: :ontology_submission, attribute: :usedOntologyEngineeringTool}
            attribute_mapped :accrualMethod, namespace: :dcterms, mapped_to: {model: :ontology_submission, attribute: :accrualMethod}
            attribute_mapped :accrualPeriodicity, namespace: :dcterms, mapped_to: {model: :ontology_submission, attribute: :accrualPeriodicity}
            attribute_mapped :accrualPolicy, namespace: :dcterms, mapped_to: {model: :ontology_submission, attribute: :accrualPolicy}
            attribute_mapped :competencyQuestion, namespace: :mod, mapped_to: {model: :ontology_submission, attribute: :competencyQuestion}
            attribute_mapped :wasGeneratedBy, namespace: :prov, mapped_to: {model: :ontology_submission, attribute: :wasGeneratedBy}
            attribute_mapped :wasInvalidatedBy, namespace: :prov, mapped_to: {model: :ontology_submission, attribute: :wasInvalidatedBy}
            attribute_mapped :isFormatOf, namespace: :dcterms, mapped_to: {model: :ontology_submission, attribute: :isFormatOf}
            attribute_mapped :hasFormat, namespace: :dcterms, mapped_to: {model: :ontology_submission, attribute: :hasFormat}
            attribute_mapped :uriLookupEndpoint, namespace: :void, mapped_to: {model: :ontology_submission, attribute: :uriLookupEndpoint}
            attribute_mapped :openSearchDescription, namespace: :void, mapped_to: {model: :ontology_submission, attribute: :openSearchDescription}
            attribute_mapped :source, namespace: :dcterms, mapped_to: {model: :ontology_submission, attribute: :source}
            attribute_mapped :includedInDataCatalog, namespace: :schema, mapped_to: {model: :ontology_submission, attribute: :includedInDataCatalog}
            attribute_mapped :priorVersion, namespace: :owl, mapped_to: {model: :ontology_submission, attribute: :hasPriorVersion}
            attribute_mapped :hasPart, namespace: :dcterms, mapped_to: {model: :ontology_submission, attribute: :hasPart}
            attribute_mapped :relation, namespace: :dcterms, mapped_to: {model: :ontology_submission, attribute: :ontologyRelatedTo}
            attribute_mapped :semanticArtefactRelation, namespace: :mod, mapped_to: {model: :ontology_submission, attribute: :ontologyRelatedTo}
            attribute_mapped :specializes, namespace: :mod, mapped_to: {model: :ontology_submission, attribute: :explanationEvolution}
            attribute_mapped :generalizes, namespace: :mod, mapped_to: {model: :ontology_submission, attribute: :generalizes}
            attribute_mapped :usedBy, namespace: :mod, mapped_to: {model: :ontology_submission, attribute: :usedBy}
            attribute_mapped :reliesOn, namespace: :mod, mapped_to: {model: :ontology_submission, attribute: :ontologyRelatedTo}
            attribute_mapped :similar, namespace: :mod, mapped_to: {model: :ontology_submission, attribute: :similarTo}
            attribute_mapped :comesFromTheSameDomain, namespace: :mod, mapped_to: {model: :ontology_submission, attribute: :comesFromTheSameDomain}
            attribute_mapped :hasEquivalencesWith, namespace: :mod, mapped_to: {model: :ontology_submission, attribute: :isAlignedTo}
            attribute_mapped :backwardCompatibleWith, namespace: :owl, mapped_to: {model: :ontology_submission, attribute: :isBackwardCompatibleWith}
            attribute_mapped :incompatibleWith, namespace: :owl, mapped_to: {model: :ontology_submission, attribute: :isIncompatibleWith}
            attribute_mapped :hasDisparateModellingWith, namespace: :mod, mapped_to: {model: :ontology_submission, attribute: :hasDisparateModelling}
            attribute_mapped :hasDisjunctionsWith, namespace: :mod, mapped_to: {model: :ontology_submission, attribute: :hasDisjunctionsWith}
            attribute_mapped :workTranslation, namespace: :schema, mapped_to: {model: :ontology_submission, attribute: :workTranslation}
            attribute_mapped :translationOfWork, namespace: :schema, mapped_to: {model: :ontology_submission, attribute: :translationOfWork}
            attribute_mapped :uriRegexPattern, namespace: :void, mapped_to: {model: :ontology_submission, attribute: :uriRegexPattern}
            attribute_mapped :preferredNamespaceUri, namespace: :vann, mapped_to: {model: :ontology_submission, attribute: :preferredNamespaceUri}
            attribute_mapped :preferredNamespacePrefix, namespace: :vann, mapped_to: {model: :ontology_submission, attribute: :preferredNamespacePrefix}
            attribute_mapped :exampleResource, namespace: :void, mapped_to: {model: :ontology_submission, attribute: :exampleIdentifier}
            attribute_mapped :primaryTopic, namespace: :foaf, mapped_to: {model: :ontology_submission, attribute: :keyClasses}
            attribute_mapped :rootResource, namespace: :void, mapped_to: {model: :ontology_submission, attribute: :roots}
            attribute_mapped :changes, namespace: :vann, mapped_to: {model: :ontology_submission, attribute: :diffFilePath}
            attribute_mapped :associatedMedia, namespace: :schema, mapped_to: {model: :ontology_submission, attribute: :associatedMedia}
            attribute_mapped :depiction, namespace: :foaf, mapped_to: {model: :ontology_submission, attribute: :depiction}
            attribute_mapped :logo, namespace: :foaf, mapped_to: {model: :ontology_submission, attribute: :logo}
            attribute_mapped :metrics, namespace: :mod, mapped_to: {model: :ontology_submission, attribute: :metrics}


            attribute :ontology, type: :ontology
            
            links_load :acronym
            link_to LinkedData::Hypermedia::Link.new("distributions", lambda {|s| "artefacts/#{s.acronym}/distributions"}, LinkedData::Models::SemanticArtefactDistribution.type_uri),
                    LinkedData::Hypermedia::Link.new("record", lambda {|s| "artefacts/#{s.acronym}/record"}),
                    LinkedData::Hypermedia::Link.new("resources", lambda {|s| "artefacts/#{s.acronym}/resources"}),
                    LinkedData::Hypermedia::Link.new("single_resource", lambda {|s| "artefacts/#{s.acronym}/resources/{:resourceID}"}),
                    LinkedData::Hypermedia::Link.new("classes", lambda {|s| "artefacts/#{s.acronym}/classes"}, LinkedData::Models::Class.uri_type),
                    LinkedData::Hypermedia::Link.new("concepts", lambda {|s| "artefacts/#{s.acronym}/concepts"}, LinkedData::Models::Class.uri_type),
                    LinkedData::Hypermedia::Link.new("properties", lambda {|s| "artefacts/#{s.acronym}/properties"}, "#{Goo.namespaces[:metadata].to_s}Property"),
                    LinkedData::Hypermedia::Link.new("individuals", lambda {|s| "artefacts/#{s.acronym}/classes/roots"}, LinkedData::Models::Class.uri_type),
                    LinkedData::Hypermedia::Link.new("schemes", lambda {|s| "artefacts/#{s.acronym}/schemes"}, LinkedData::Models::SKOS::Scheme.uri_type),
                    LinkedData::Hypermedia::Link.new("collection", lambda {|s| "artefacts/#{s.acronym}/collections"}, LinkedData::Models::SKOS::Collection.uri_type),
                    LinkedData::Hypermedia::Link.new("labels", lambda {|s| "artefacts/#{s.acronym}/labels"}, LinkedData::Models::SKOS::Label.uri_type)

            
            serialize_default :acronym, :accessRights, :subject, :URI, :versionIRI, :creator, :identifier, :status, :language, 
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

            def initialize
                super
            end

            def self.type_uri
                self.namespace[self.model_name].to_s
            end

            def self.find(artefact_id)
                ont = Ontology.find(artefact_id).include(:acronym).first
                return nil unless ont

                new.tap do |sa|
                    sa.ontology = ont
                    sa.acronym = ont.acronym
                end
            end

            # Method to fetch specific attributes and populate the SemanticArtefact instance
            def bring(*attributes)
                attributes = [attributes] unless attributes.is_a?(Array)
                latest = @ontology.latest_submission(status: :ready)
                attributes.each do |attr|
                    mapping = self.class.attribute_mappings[attr]
                    next if mapping.nil?

                    model = mapping[:model]
                    mapped_attr = mapping[:attribute]
                    
                    case model
                    when :ontology
                        @ontology.bring(*mapped_attr)
                        self.send("#{attr}=", @ontology.send(mapped_attr)) if @ontology.respond_to?(mapped_attr)
                    when :ontology_submission
                        if latest
                            latest.bring(*mapped_attr)
                            self.send("#{attr}=", latest.send(mapped_attr))
                        end
                    end
                end
            end

            def self.all_artefacts(options = {})
                onts = if options[:also_include_views]
                        Ontology.where.to_a
                    else
                        Ontology.where.filter(Goo::Filter.new(:viewOf).unbound).include(:acronym).to_a
                    end
        
                onts.map do |o|
                    new.tap do |sa|
                        sa.ontology = o
                        sa.acronym = o.acronym
                        sa.bring(*options[:includes]) if options[:includes]
                    end
                end
            end

            def latest_distribution(status)
                sub = @ontology.latest_submission(status)
                SemanticArtefactDistribution.new(sub) unless sub.nil?
            end

            def distribution(dist_id)
                sub = @ontology.submission(dist_id)
                SemanticArtefactDistribution.new(sub) unless sub.nil?
            end
        
            def all_distributions(options = {})
                to_bring = options[:includes]
                @ontology.bring(:submissions)
        
                @ontology.submissions.map do |submission|
                    SemanticArtefactDistribution.new(submission).tap do |dist|
                        dist.bring(*to_bring) if to_bring
                    end
                end
            end
    
            def analytics
                @ontology.analytics
            end
            
        end
    end
end
