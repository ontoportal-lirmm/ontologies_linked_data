require 'yaml'
require 'ontologies_linked_data/models/ontology'
require 'ontologies_linked_data/models/project'
require 'ontologies_linked_data/models/notes/note'
require 'ontologies_linked_data/models/users/user'
require 'ontologies_linked_data/models/agents/agent'
require 'ontologies_linked_data/models/group'
require 'ontologies_linked_data/models/slice'
require 'ontologies_linked_data/models/mappings/mapping'
require 'ontologies_linked_data/models/project'
require 'ontologies_linked_data/models/category'
require 'ontologies_linked_data/models/provisional_class'
require 'ontologies_linked_data/models/provisional_relation'
require 'ontologies_linked_data/models/metric'
require 'ontologies_linked_data/models/review'

module LinkedData
    module Models
        class SemanticArtefactCatalog < LinkedData::Models::ModBase


            model :SemanticArtefactCatalog, namespace: :mod, scheme: File.join(__dir__, '../../../../config/schemes/semantic_artefact_catalog.yml'),
                                                            name_with: ->(s) { RDF::URI.new(LinkedData.settings.id_url_prefix) }


            attribute :acronym, namespace: :omv, enforce: [:unique, :string]
            attribute :title, namespace: :dcterms, enforce: [:string]
            attribute :color, enforce: [:string, :valid_hash_code]
            attribute :description, namespace: :dcterms, enforce: [:string]
            attribute :versionInfo, namespace: :owl, enforce: [:string]
            attribute :identifier, namespace: :dcterms, enforce: [:string]
            attribute :status, namespace: :mod, enforce: [:string]
            attribute :accessRights, namespace: :dcterms, enforce: [:string]
            attribute :useGuidelines, namespace: :cc, enforce: [:string]
            attribute :morePermissions, namespace: :cc, enforce: [:string]
            attribute :abstract, namespace: :dcterms, enforce: [:string]
            attribute :group, namespace: :mod, enforce: [:string]
            attribute :audience, namespace: :dcterms, enforce: [:string]
            attribute :repository, namespace: :doap, enforce: [:string]
            attribute :bugDatabase, namespace: :doap, enforce: [:string]
            attribute :relation, namespace: :dcterms, enforce: [:string]
            attribute :hasPolicy, namespace: :mod, enforce: [:string]
            attribute :themeTaxonomy, namespace: :mod, enforce: [:string]
            
            attribute :created, namespace: :dcterms, enforce: [:date]
            attribute :curatedOn, namespace: :pav, enforce: [:date]
            
            attribute :deprecated, namespace: :owl, enforce: [:boolean]
            
            attribute :homepage, namespace: :foaf, enforce: [:url], default: ->(s) { RDF::URI("http://#{LinkedData.settings.ui_host}") }
            attribute :logo, namespace: :foaf, enforce: [:url]
            attribute :license, namespace: :dcterms, enforce: [:url]
            attribute :mailingList, namespace: :mod, enforce: [:url]
            attribute :fairScore, namespace: :mod, enforce: [:url]
            
            attribute :federated_portals, enforce: [:list]
            attribute :fundedBy, namespace: :foaf, enforce: [:list]
            attribute :language, namespace: :dcterms, enforce: [:list]
            attribute :comment, namespace: :rdfs, enforce: [:list]
            attribute :keyword, namespace: :dcat, enforce: [:list]
            attribute :alternative, namespace: :dcterms, enforce: [:list]
            attribute :hiddenLabel, namespace: :skos, enforce: [:list]
            attribute :bibliographicCitation, namespace: :dcterms, enforce: [:list]
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
            attribute :changes, namespace: :vann, enforce: [:list]
            attribute :associatedMedia, namespace: :schema, enforce: [:list]
            attribute :depiction, namespace: :foaf, enforce: [:list]
            attribute :isReferencedBy, namespace: :mod, enforce: [:list]
            attribute :funding, namespace: :mod, enforce: [:list]
            attribute :qualifiedAttribution, namespace: :mod, enforce: [:list]
            attribute :publishingPrinciples, namespace: :mod, enforce: [:list]
            attribute :qualifiedRelation, namespace: :mod, enforce: [:list]
            attribute :catalog, namespace: :mod, enforce: [:list]
            
            attribute :rightsHolder, namespace: :dcterms, type: %i[Agent]
            attribute :contactPoint, namespace: :dcat, type: %i[list Agent]
            attribute :creator, namespace: :dcterms, type: %i[list Agent]
            attribute :contributor, namespace: :dcterms, type: %i[list Agent]
            attribute :curatedBy, namespace: :pav, type: %i[list Agent]
            attribute :translator, namespace: :schema, type: %i[list Agent]
            attribute :publisher, namespace: :dcterms, type: %i[list Agent]
            attribute :endorsedBy, namespace: :mod, type: %i[list Agent]

            # Computed Values
            attribute :landingPage, namespace: :dcat, enforce: [:url], handler: :ui_url
            attribute :modified, namespace: :dcterms, enforce: [:date_time], handler: :modification_date
            attribute :usedInProject, namespace: :mod, enforce: [:url], handler: :projects_url
            attribute :analytics, namespace: :mod, enforce: [:url], handler: :analytics_url
            attribute :accessURL, namespace: :dcat, enforce: [:url], handler: :api_url
            attribute :uriLookupEndpoint, namespace: :void, enforce: [:url], handler: :search_url
            attribute :openSearchDescription, namespace: :void, enforce: [:url], handler: :search_url
            attribute :endpoint, namespace: :sd, enforce: [:url], handler: :sparql_url
            attribute :uriRegexPattern, namespace: :void, enforce: [:url], handler: :set_uri_regex_pattern
            attribute :preferredNamespaceUri, namespace: :vann, enforce: [:url], handler: :set_preferred_namespace_uri
            attribute :preferredNamespacePrefix, namespace: :vann, enforce: [:url], handler: :set_preferred_namespace_prefix
            attribute :metadataVoc, namespace: :mod, enforce: [:url], handler: :set_metadata_voc
            attribute :featureList, namespace: :schema, enforce: [:url], handler: :set_feature_list
            attribute :supportedSchema, namespace: :adms, enforce: [:url], handler: :set_supported_schema
            attribute :conformsTo, namespace: :dcterms, enforce: [:url], handler: :mod_uri
            attribute :dataset, namespace: :dcat, enforce: [:url], handler: :artefacts_url
            attribute :service, namespace: :dcat, enforce: [:url], handler: :get_services
            attribute :record, namespace: :dcat, enforce: [:url], handler: :records_url
            attribute :distribution, namespace: :dcat, enforce: [:url], handler: :distributions_url
            attribute :numberOfArtefacts, namespace: :mod, enforce: [:integer], handler: :ontologies_count
            attribute :metrics, namespace: :mod, enforce: [:url], handler: :metrics_url
            attribute :numberOfUsers, namespace: :mod, enforce: [:integer], handler: :users_counts

            METRICS_ATTRIBUTES = {
                numberOfClasses: { mapped_to: :classes, handler: :class_count },
                numberOfIndividuals: { mapped_to: :individuals, handler: :individuals_count },
                numberOfProperties: { mapped_to: :properties, handler: :properties_count },
                numberOfAxioms: :axioms_counts,
                numberOfObjectProperties: :object_properties_counts,
                numberOfDataProperties: :data_properties_counts,
                numberOfLabels: :labels_counts,
                numberOfDeprecated: :deprecated_counts,
                numberOfUsingProjects: :using_projects_counts,
                numberOfEndorsements: :endorsements_counts,
                numberOfMappings: :mappings_counts,
                numberOfAgents: :agents_counts
            }
              
            METRICS_ATTRIBUTES.each do |attr_name, config|
                handler = config.is_a?(Hash) ? config[:handler] : config
                mapped_to = config.is_a?(Hash) ? config[:mapped_to] : attr_name
                attribute attr_name, namespace: :mod, enforce: [:integer], handler: handler
                define_method(handler) { calculate_attr_from_metrics(mapped_to) }
            end

            link_to LinkedData::Hypermedia::Link.new("doc/legacy-api", lambda {|s| "documentation"}, nil),
                    LinkedData::Hypermedia::Link.new("doc/mod-api", lambda {|s| "doc/api"}, nil),
                    LinkedData::Hypermedia::Link.new("ontologies", lambda {|s| "ontologies"},  LinkedData::Models::Ontology.type_uri),
                    LinkedData::Hypermedia::Link.new("ontologies_full", lambda {|s| "ontologies_full"}, LinkedData::Models::Ontology.type_uri),
                    LinkedData::Hypermedia::Link.new("ontology_metadata", lambda {|s| "ontology_metadata"}, nil),
                    LinkedData::Hypermedia::Link.new("submissions", lambda {|s| "submissions"}, LinkedData::Models::OntologySubmission.type_uri),
                    LinkedData::Hypermedia::Link.new("submission_metadata", lambda {|s| "submission_metadata"}, nil),
                    LinkedData::Hypermedia::Link.new("artefacts", lambda {|s| "artefacts"}, LinkedData::Models::SemanticArtefact.type_uri),
                    LinkedData::Hypermedia::Link.new("records", lambda {|s| "records"}, LinkedData::Models::SemanticArtefactCatalogRecord.type_uri),
                    LinkedData::Hypermedia::Link.new("users", lambda {|s| "users"}, LinkedData::Models::User.type_uri),
                    LinkedData::Hypermedia::Link.new("agents", lambda {|s| "agents"}, LinkedData::Models::Agent.type_uri),
                    LinkedData::Hypermedia::Link.new("groups", lambda {|s| "groups"}, LinkedData::Models::Group.type_uri),
                    LinkedData::Hypermedia::Link.new("slices", lambda {|s| "slices"}, LinkedData::Models::Slice.type_uri),
                    LinkedData::Hypermedia::Link.new("mappings", lambda {|s| "mappings"}, LinkedData::Models::Mapping.type_uri.to_s),
                    LinkedData::Hypermedia::Link.new("projects", lambda {|s| "projects"}, LinkedData::Models::Project.type_uri),
                    LinkedData::Hypermedia::Link.new("categories", lambda {|s| "categories"}, LinkedData::Models::Category.type_uri),
                    LinkedData::Hypermedia::Link.new("provisional_classes", lambda {|s| "provisional_classes"}, LinkedData::Models::ProvisionalClass.type_uri),
                    LinkedData::Hypermedia::Link.new("provisional_relations", lambda {|s| "provisional_relations"}, LinkedData::Models::ProvisionalRelation.type_uri),
                    LinkedData::Hypermedia::Link.new("metrics", lambda {|s| "metrics"}, LinkedData::Models::Metric.type_uri),
                    LinkedData::Hypermedia::Link.new("analytics", lambda {|s| "analytics"}, nil),
                    LinkedData::Hypermedia::Link.new("search", lambda {|s| "search"}, nil),
                    LinkedData::Hypermedia::Link.new("property_search", lambda {|s| "property_search"}, nil),
                    LinkedData::Hypermedia::Link.new("recommender", lambda {|s| "recommender"}, nil),
                    LinkedData::Hypermedia::Link.new("annotator", lambda {|s| "annotator"}, nil),
                    LinkedData::Hypermedia::Link.new("notes", lambda {|s| "notes"}, LinkedData::Models::Note.type_uri),
                    LinkedData::Hypermedia::Link.new("replies", lambda {|s| "replies"}, LinkedData::Models::Notes::Reply.type_uri),
                    LinkedData::Hypermedia::Link.new("reviews", lambda {|s| "reviews"}, LinkedData::Models::Review.type_uri)
              
            serialize_default :acronym, :title, :color, :description, :logo,:identifier, :status, :language, :type, :accessRights, :license, :rightsHolder,
                              :landingPage, :keyword, :bibliographicCitation, :created, :modified , :contactPoint, :creator, :contributor, 
                              :publisher, :subject, :coverage, :createdWith, :accrualMethod, :accrualPeriodicity, :wasGeneratedBy, :accessURL,
                              :numberOfArtefacts, :federated_portals, :fundedBy

            def self.type_uri
                namespace[model_name].to_s
            end
            
            def ontologies_count
                LinkedData::Models::Ontology.where(viewingRestriction: 'public').count
            end

            def users_counts
                LinkedData::Models::User.all.count
            end

            def modification_date
                nil
            end

            def ui_url
                RDF::URI("http://#{LinkedData.settings.ui_host}")
            end

            def api_url
                RDF::URI(LinkedData.settings.id_url_prefix)
            end

            def set_uri_regex_pattern
                ""
            end

            def set_preferred_namespace_uri
                ""
            end
            
            def set_preferred_namespace_prefix
                ""
            end
            
            def set_metadata_voc
                ""
            end

            def mod_uri
                 RDF::URI("https://w3id.org/mod")
            end
            
            def set_feature_list
                []
            end
            
            def set_supported_schema
                []
            end

            def get_services
                []
            end

            %w[projects analytics search sparql metrics artefacts records distributions].each do |name|
                define_method("#{name}_url") do
                    RDF::URI(LinkedData.settings.id_url_prefix).join(name)
                end
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
                @latest_metrics ||= LinkedData::Models::Metric.where.include(LinkedData::Models::Metric.goo_attrs_to_load([:all])).all
                    .group_by { |x| x.id.split('/')[-4] }
                    .transform_values { |metrics| metrics.max_by { |x| x.id.split('/')[-2].to_i } }

                @latest_metrics.values.sum do |metric|
                    metric.loaded_attributes.include?(attr) ? metric.send(attr).to_i : 0
                end
            end

        end
    end
end