require 'yaml'

module LinkedData
    module Models
        class SemanticArtefactCatalog < LinkedData::Models::Base


            model :SemanticArtefactCatalog, namespace: :mod, scheme: File.join(__dir__, '../../../../config/schemes/semantic_artefact_catalog.yml'),
                                                            name_with: ->(s) { RDF::URI.new(LinkedData.settings.id_url_prefix) }


            attribute :acronym, namespace: :omv, enforce: [:unique, :string]
            attribute :title, namespace: :dcterms, enforce: [:string]
            attribute :color, enforce: [:string, :valid_hash_code]
            attribute :description, namespace: :dcterms, enforce: [:string]
            attribute :logo, namespace: :foaf, enforce: [:uri]
            attribute :fundedBy, namespace: :foaf, enforce: [:list]
            attribute :federated_portals, enforce: [:list]
            attribute :versionInfo, namespace: :owl, enforce: [:string]
            attribute :identifier, namespace: :dcterms, enforce: [:string]
            attribute :status, namespace: :mod, enforce: [:string]
            attribute :deprecated, namespace: :owl, enforce: [:boolean]
            attribute :language, namespace: :dcterms, enforce: [:list]
            attribute :accessRights, namespace: :dcterms, enforce: [:string]
            attribute :license, namespace: :dcterms, enforce: [:uri]
            attribute :useGuidelines, namespace: :cc, enforce: [:string]
            attribute :morePermissions, namespace: :cc, enforce: [:string]
            attribute :rightsHolder, namespace: :dcterms, type: %i[Agent]
            attribute :comment, namespace: :rdfs, enforce: [:list]
            attribute :keyword, namespace: :dcat, enforce: [:list]
            attribute :alternative, namespace: :dcterms, enforce: [:list]
            attribute :hiddenLabel, namespace: :skos, enforce: [:list]
            attribute :abstract, namespace: :dcterms, enforce: [:string]
            attribute :bibliographicCitation, namespace: :dcterms, enforce: [:list]
            attribute :created, namespace: :dcterms, enforce: [:date_time]
            attribute :curatedOn, namespace: :pav, enforce: [:date_time]
            attribute :contactPoint, namespace: :dcat, type: %i[list Agent]
            attribute :creator, namespace: :dcterms, type: %i[list Agent]
            attribute :contributor, namespace: :dcterms, type: %i[list Agent]
            attribute :curatedBy, namespace: :pav, type: %i[list Agent]
            attribute :translator, namespace: :schema, type: %i[list Agent]
            attribute :publisher, namespace: :dcterms, type: %i[list Agent]
            attribute :endorsedBy, namespace: :mod, type: %i[list Agent]
            attribute :group, namespace: :mod, enforce: [:string]
            attribute :audience, namespace: :dcterms, enforce: [:string]
            attribute :repository, namespace: :doap, enforce: [:string]
            attribute :bugDatabase, namespace: :doap, enforce: [:string]
            attribute :mailingList, namespace: :doap, enforce: [:uri]
            attribute :toDoList, namespace: :mod, enforce: [:list]
            attribute :award, namespace: :schema, enforce: [:list]
            attribute :knownUsage, namespace: :mod, enforce: [:list]
            attribute :subject, namespace: :dcterms, enforce: [:list]
            attribute :coverage, namespace: :dcterms, enforce: [:list]
            attribute :example, namespace: :vann, enforce: [:list]
            attribute :createdWith, namespace: :pav, enforce: [:list]
            attribute :accrualMethod, namespace: :dcterms, enforce: [:list]
            attribute :accrualPeriodicity, namespace: :dcterms, enforce: [:list]
            attribute :accrualPolicy, namespace: :dcterms, enforce: [:list]
            attribute :wasGeneratedBy, namespace: :prov, enforce: [:list]
            attribute :source, namespace: :dcterms, enforce: [:list]
            attribute :isPartOf, namespace: :dcterms, enforce: [:list]
            attribute :hasPart, namespace: :dcterms, enforce: [:list]
            attribute :relation, namespace: :dcterms, enforce: [:string]
            attribute :changes, namespace: :vann, enforce: [:list]
            attribute :associatedMedia, namespace: :schema, enforce: [:list]
            attribute :depiction, namespace: :foaf, enforce: [:list]
            attribute :hasPolicy, namespace: :mod, enforce: [:string]
            attribute :isReferencedBy, namespace: :mod, enforce: [:list]
            attribute :funding, namespace: :mod, enforce: [:list]
            attribute :qualifiedAttribution, namespace: :mod, enforce: [:list]
            attribute :publishingPrinciples, namespace: :mod, enforce: [:list]
            attribute :qualifiedRelation, namespace: :mod, enforce: [:list]
            attribute :fairScore, namespace: :mod, enforce: [:uri]
            attribute :catalog, namespace: :mod, enforce: [:list]
            attribute :record, namespace: :mod, enforce: [:uri]
            attribute :themeTaxonomy, namespace: :mod, enforce: [:string]
            attribute :distribution, namespace: :mod, enforce: [:uri]
            attribute :landingPage, namespace: :dcat, enforce: [:uri]
            attribute :usedInProject, namespace: :mod, type: %i[list Project]
            attribute :analytics, namespace: :mod, enforce: [:uri]
            attribute :accessURL, namespace: :dcat, enforce: [:uri]
            attribute :uriLookupEndpoint, namespace: :void, enforce: [:uri]
            attribute :openSearchDescription, namespace: :void, enforce: [:string]
            attribute :endpoint, namespace: :sd, enforce: [:uri]
            attribute :uriRegexPattern, namtitleespace: :void, enforce: [:string]
            attribute :preferredNamespaceUri, namespace: :vann, enforce: [:string]
            attribute :preferredNamespacePrefix, namespace: :vann, enforce: [:string]
            attribute :metadataVoc, namespace: :mod, enforce: [:string]
            attribute :dataset, namespace: :mod, enforce: [:uri]
            attribute :service, namespace: :mod, enforce: [:list]
            
            attribute :homepage, namespace: :foaf, enforce: [:uri], handler: :set_home_page
            attribute :modified, namespace: :dcterms, enforce: [:date_time], handler: :modification_date
            attribute :numberOfArtefacts, namespace: :mod, enforce: [:integer], handler: :ontologies_count
            attribute :metrics, namespace: :mod, enforce: [:uri], handler: :generate_metrics
            attribute :numberOfClasses, namespace: :mod, enforce: [:integer], handler: :class_count
            attribute :numberOfIndividuals, namespace: :mod, enforce: [:integer], handler: :individuals_count
            attribute :numberOfProperties, namespace: :mod, enforce: [:integer], handler: :propoerties_count
            attribute :numberOfAxioms, namespace: :mod, enforce: [:integer], handler: :axioms_counts
            attribute :numberOfObjectProperties, namespace: :mod, enforce: [:integer], handler: :object_properties_counts
            attribute :numberOfDataProperties, namespace: :mod, enforce: [:integer], handler: :data_properties_counts
            attribute :numberOfLabels, namespace: :mod, enforce: [:integer], handler: :labels_counts
            attribute :numberOfDeprecated, namespace: :mod, enforce: [:integer], handler: :deprecated_counts
            attribute :numberOfUsingProjects, namespace: :mod, enforce: [:integer], handler: :using_projects_counts
            attribute :numberOfEndorsements, namespace: :mod, enforce: [:integer], handler: :endorsements_counts
            attribute :numberOfMappings, namespace: :mod, enforce: [:integer], handler: :mappings_counts
            attribute :numberOfUsers, namespace: :mod, enforce: [:integer], handler: :users_counts
            attribute :numberOfAgents, namespace: :mod, enforce: [:integer], handler: :agents_counts

            serialize_default :acronym, :title, :color, :description, :logo, :fundedBy, :versionInfo, :homepage, :numberOfArtefacts, :federated_portals

            def ontologies_count
                LinkedData::Models::Ontology.where(viewingRestriction: 'public').count
            end

            def modification_date
                Date.new(2025, 1, 1)
            end

            def set_home_page
                RDF::URI(LinkedData.settings.ui_host)
            end

            def generate_metrics
                RDF::URI(LinkedData.settings.id_url_prefix).join('metrics')
            end  
            
            def class_count
                calculate_attr_from_metrics(:classes)
            end
            
            def individuals_count
                calculate_attr_from_metrics(:individuals)
            end
            
            def propoerties_count
                calculate_attr_from_metrics(:properties)
            end
            
            def axioms_counts
                calculate_attr_from_metrics(:numberOfAxioms)
            end
            
            def object_properties_counts
                calculate_attr_from_metrics(:numberOfObjectProperties)
            end
            
            def data_properties_counts
                calculate_attr_from_metrics(:numberOfDataProperties)
            end
            
            def labels_counts
                calculate_attr_from_metrics(:numberOfLabels)
            end
            
            def deprecated_counts
                calculate_attr_from_metrics(:numberOfDeprecated)
            end
            
            def using_projects_counts
                calculate_attr_from_metrics(:numberOfUsingProjects)
            end
            
            def endorsements_counts
                calculate_attr_from_metrics(:numberOfEnsorments)
            end
            
            def mappings_counts
                calculate_attr_from_metrics(:numberOfMappings)
            end
            
            def users_counts
                LinkedData::Models::User.all.count
            end
            
            def agents_counts
                LinkedData::Models::Agent.all.count
            end

            def self.valid_hash_code(inst, attr)
                inst.bring(attr) if inst.bring?(attr)
                str = inst.send(attr)
        
                return if (/^#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6})$/ === str)
                [:valid_hash_code,
                 "Invalid hex color code: '#{str}'. Please provide a valid hex code in the format '#FFF' or '#FFFFFF'."]
            end

            private

            def calculate_attr_from_metrics(attr)
                attr_to_get = attr.to_sym
                submissions_query = LinkedData::Models::OntologySubmission
                submissions_query = submissions_query.where
                submissions = submissions_query.include(OntologySubmission.goo_attrs_to_load([attr_to_get]))
                metrics_include = LinkedData::Models::Metric.goo_attrs_to_load([attr_to_get])
                LinkedData::Models::OntologySubmission.where.models(submissions).include(metrics: metrics_include).all
                somme = 0
                submissions.each do |x|
                    if x.metrics
                      begin
                        somme += x.metrics.send(attr_to_get)
                      rescue
                        next
                      end
                    end
                end
                somme
            end

        end
    end
end