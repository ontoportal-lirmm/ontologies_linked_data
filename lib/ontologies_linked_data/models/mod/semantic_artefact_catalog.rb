require 'yaml'

module LinkedData
    module Models
        class SemanticArtefactCatalog < LinkedData::Models::Base


            # Load the scheme file once
            SCHEME_PATH = File.join(__dir__, '../../../../config/schemes/semantic_artefact_catalog.yml')
            SCHEME = YAML.load_file(SCHEME_PATH)

            class << self
                def define_attribute(name, **options)
                    options[:default] = ->(x) { SCHEME.dig(name.to_s, 'default') }
                    attribute(name, **options)
                end
            end

            model :SemanticArtefactCatalog, namespace: :mod, name_with: ->(s) { RDF::URI.new(LinkedData.settings.id_url_prefix) }

            define_attribute :acronym, namespace: :omv, enforce: [:unique]
            define_attribute :title, namespace: :dcterms, enforce: [:string]
            define_attribute :color, enforce: [:valid_hash_code]
            define_attribute :description, namespace: :dcterms, enforce: [:string]
            define_attribute :logo, namespace: :foaf, enforce: [:url]
            define_attribute :versionInfo, namespace: :owl, enforce: [:string]
            define_attribute :fundedBy, namespace: :foaf, enforce: [:list]
            define_attribute :federated_portals, enforce: [:list]



            # SAD attrs that map with submission
            define_attribute :homepage, namespace: :foaf, enforce: [:url]
            define_attribute :identifier, namespace: :dcterms, enforce: [:url]
            define_attribute :status, namespace: :mod, enforce: [:string]
            define_attribute :deprecated, namespace: :owl, enforce: [:boolean]
            define_attribute :language, namespace: :dcterms, enforce: [:string]
            define_attribute :accessRights, namespace: :dcterms, enforce: [:string]
            define_attribute :license, namespace: :dcterms, enforce: [:url]
            define_attribute :useGuidelines, namespace: :cc
            define_attribute :morePermissions, namespace: :cc
            define_attribute :rightsHolder, namespace: :dcterms
            define_attribute :landingPage, namespace: :dcat
            define_attribute :comment, namespace: :rdfs, enforce: [:string]
            define_attribute :keyword, namespace: :dcat, enforce: [:list]
            define_attribute :alternative, namespace: :dcterms
            define_attribute :hiddenLabel, namespace: :skos
            define_attribute :abstract, namespace: :dcterms, enforce: [:string]
            define_attribute :bibliographicCitation, namespace: :dcterms
            define_attribute :created, namespace: :dcterms, enforce: [:date]
            define_attribute :curatedOn, namespace: :pav, enforce: [:date]
            define_attribute :contactPoint, namespace: :dcat, enforce: [:date]
            define_attribute :creator, namespace: :dcterms, enforce: [:date]
            define_attribute :contributor, namespace: :dcterms, enforce: [:string]
            define_attribute :curatedBy, namespace: :pav
            define_attribute :translator, namespace: :schema
            define_attribute :publisher, namespace: :dcterms
            define_attribute :endorsedBy, namespace: :mod
            define_attribute :comment, namespace: :schema
            define_attribute :group, namespace: :mod
            define_attribute :usedInProject, namespace: :mod
            define_attribute :audience, namespace: :dcterms
            define_attribute :analytics, namespace: :mod
            define_attribute :repository, namespace: :doap
            define_attribute :bugDatabase, namespace: :doap
            define_attribute :mailingList, namespace: :doap
            define_attribute :toDoList, namespace: :mod
            define_attribute :award, namespace: :schema
            define_attribute :knownUsage, namespace: :mod
            define_attribute :subject, namespace: :dcterms
            define_attribute :coverage, namespace: :dcterms
            define_attribute :example, namespace: :vann
            define_attribute :createdWith, namespace: :pav
            define_attribute :accrualMethod, namespace: :dcterms
            define_attribute :accrualPeriodicity, namespace: :dcterms
            define_attribute :accrualPolicy, namespace: :dcterms
            define_attribute :wasGeneratedBy, namespace: :prov
            define_attribute :accessURL, namespace: :dcat
            define_attribute :uriLookupEndpoint, namespace: :void
            define_attribute :openSearchDescription, namespace: :void
            define_attribute :source, namespace: :dcterms
            define_attribute :endpoint, namespace: :sd
            define_attribute :isPartOf, namespace: :dcterms
            define_attribute :hasPart, namespace: :dcterms
            define_attribute :relation, namespace: :dcterms
            define_attribute :uriRegexPattern, namtitleespace: :void
            define_attribute :preferredNamespaceUri, namespace: :vann
            define_attribute :preferredNamespacePrefix, namespace: :vann
            define_attribute :metadataVoc, namespace: :mod
            define_attribute :changes, namespace: :vann
            define_attribute :associatedMedia, namespace: :schema
            define_attribute :depiction, namespace: :foaf
            define_attribute :hasPolicy, namespace: :mod
            define_attribute :isReferencedBy, namespace: :mod
            define_attribute :funding, namespace: :mod
            define_attribute :qualifiedAttribution, namespace: :mod
            define_attribute :publishingPrinciples, namespace: :mod
            define_attribute :qualifiedRelation, namespace: :mod
            define_attribute :fairScore, namespace: :mod
            define_attribute :featureList, namespace: :mod, enforce: [:list]
            define_attribute :supportedSchema, namespace: :mod
            define_attribute :conformsTo, namespace: :mod
            define_attribute :catalog, namespace: :mod
            define_attribute :dataset, namespace: :mod
            define_attribute :service, namespace: :mod
            define_attribute :record, namespace: :mod
            define_attribute :themeTaxonomy, namespace: :mod
            define_attribute :distribution, namespace: :mod

            attribute :modified, namespace: :dcterms, enforce: [:date], handler: :modification_date
            attribute :numberOfArtefacts, namespace: :mod, enforce: [:integer], handler: :ontologies_count
            attribute :metrics, namespace: :mod, enforce: [:list], handler: :generate_metrics
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
            
            attribute :test_attr_to_persist
            serialize_never :test_attr_to_persist

            serialize_default :acronym, :title, :color, :description, :logo, :fundedBy, :versionInfo, :homepage, :numberOfArtefacts, :federated_portals

            def bring(*attributes)
                attributes = [attributes] unless attributes.is_a?(Array)
                super(*attributes - computed_attrs)
                # bring computed attrs if there are ones
                computed_attrs.each do |attr|
                    self.send(attr)
                end
            end

            def federated_portals_settings
                LinkedData.settings.federated_portals.symbolize_keys
            end

            def computed_attrs
                [
                    :numberOfArtefacts, :metrics, :numberOfClasses, :numberOfIndividuals, :numberOfProperties,
                    :numberOfAxioms, :numberOfObjectProperties, :numberOfDataProperties, :numberOfLabels, :numberOfDeprecated,
                    :numberOfUsingProjects, :numberOfEndorsements, :numberOfMappings, :numberOfUsers,:numberOfAgents
                ]
            end

            def ontologies_count
                LinkedData::Models::Ontology.where(viewingRestriction: 'public').count
            end

            def modification_date
                Date.new(2025, 1, 1)
            end

            def generate_metrics
                0
            end
            
            def class_count
                0
            end
            
            def individuals_count
                0
            end
            
            def propoerties_count
                0
            end
            
            def axioms_counts
                0
            end
            
            def object_properties_counts
                0
            end
            
            def data_properties_counts
                0
            end
            
            def labels_counts
                0
            end
            
            def deprecated_counts
                0
            end
            
            def using_projects_counts
                0
            end
            
            def endorsements_counts
                0
            end
            
            def mappings_counts
                0
            end
            
            def users_counts
                0
            end
            
            def agents_counts
                0
            end

            def self.valid_hash_code(inst, attr)
                inst.bring(attr) if inst.bring?(attr)
                str = inst.send(attr)
        
                return if (/^#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6})$/ === str)
                [:valid_hash_code,
                 "Invalid hex color code: '#{str}'. Please provide a valid hex code in the format '#FFF' or '#FFFFFF'."]
            end

        end
    end
end