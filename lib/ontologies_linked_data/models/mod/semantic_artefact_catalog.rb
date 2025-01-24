module LinkedData
    module Models
        class SemanticArtefactCatalog < LinkedData::Models::Base

            model :SemanticArtefactCatalog, namespace: :mod, scheme: File.join(__dir__, '../../../../config/schemes/semantic_artefact_catalog.yml'),
                                                        name_with: ->(s) { RDF::URI.new(LinkedData.settings.id_url_prefix) }
            
            # SAD attrs that map with submission
            attribute :acronym, namespace: :omv, enforce: [:unique], :default => lambda {|x| LinkedData.settings.ui_name.downcase}
            attribute :title, namespace: :dcterms, enforce: [:string]
            attribute :color, enforce: [:valid_hash_code]
            attribute :description, namespace: :dcterms, enforce: [:string]
            attribute :logo, namespace: :foaf, enforce: [:url]
            attribute :federated_portals, enforce: [:list]
            attribute :fundedBy, namespace: :foaf, enforce: [:list]
            attribute :versionInfo, namespace: :owl, enforce: [:string]
            attribute :homepage, namespace: :foaf, enforce: [:url]
            attribute :identifier, namespace: :dcterms, enforce: [:url]
            attribute :status, namespace: :mod, enforce: [:string]
            attribute :deprecated, namespace: :owl, enforce: [:boolean], :default => lambda {|x| false}
            attribute :language, namespace: :dcterms, enforce: [:string]
            attribute :accessRights, namespace: :dcterms, enforce: [:string], :default => lambda {|x| "public"}
            attribute :license, namespace: :dcterms, enforce: [:url]
            attribute :useGuidelines, namespace: :cc
            attribute :morePermissions, namespace: :cc
            attribute :rightsHolder, namespace: :dcterms
            attribute :landingPage, namespace: :dcat
            attribute :comment, namespace: :rdfs, enforce: [:string]
            attribute :keyword, namespace: :dcat, enforce: [:list]
            attribute :alternative, namespace: :dcterms
            attribute :hiddenLabel, namespace: :skos
            attribute :abstract, namespace: :dcterms, enforce: [:string]
            attribute :bibliographicCitation, namespace: :dcterms
            attribute :created, namespace: :dcterms, enforce: [:date]
            attribute :modified, namespace: :dcterms, enforce: [:date]
            attribute :curatedOn, namespace: :pav, enforce: [:date]
            attribute :contactPoint, namespace: :dcat
            attribute :creator, namespace: :dcterms
            attribute :contributor, namespace: :dcterms
            attribute :curatedBy, namespace: :pav
            attribute :translator, namespace: :schema
            attribute :publisher, namespace: :dcterms
            attribute :endorsedBy, namespace: :mod
            attribute :comment, namespace: :schema
            attribute :group, namespace: :mod
            attribute :usedInProject, namespace: :mod
            attribute :audience, namespace: :dcterms
            attribute :analytics, namespace: :mod
            attribute :repository, namespace: :doap
            attribute :bugDatabase, namespace: :doap
            attribute :mailingList, namespace: :doap
            attribute :toDoList, namespace: :mod
            attribute :award, namespace: :schema
            attribute :knownUsage, namespace: :mod
            attribute :subject, namespace: :dcterms
            attribute :coverage, namespace: :dcterms
            attribute :example, namespace: :vann
            attribute :createdWith, namespace: :pav
            attribute :accrualMethod, namespace: :dcterms
            attribute :accrualPeriodicity, namespace: :dcterms
            attribute :accrualPolicy, namespace: :dcterms
            attribute :wasGeneratedBy, namespace: :prov
            attribute :accessURL, namespace: :dcat
            attribute :uriLookupEndpoint, namespace: :void
            attribute :openSearchDescription, namespace: :void
            attribute :source, namespace: :dcterms
            attribute :endpoint, namespace: :sd
            attribute :isPartOf, namespace: :dcterms
            attribute :hasPart, namespace: :dcterms
            attribute :relation, namespace: :dcterms
            attribute :uriRegexPattern, namtitleespace: :void
            attribute :preferredNamespaceUri, namespace: :vann
            attribute :preferredNamespacePrefix, namespace: :vann
            attribute :metadataVoc, namespace: :mod
            attribute :changes, namespace: :vann
            attribute :associatedMedia, namespace: :schema
            attribute :depiction, namespace: :foaf
            attribute :hasPolicy, namespace: :mod
            attribute :isReferencedBy, namespace: :mod
            attribute :funding, namespace: :mod
            attribute :qualifiedAttribution, namespace: :mod
            attribute :publishingPrinciples, namespace: :mod
            attribute :qualifiedRelation, namespace: :mod
            attribute :fairScore, namespace: :mod
            attribute :featureList, namespace: :mod
            attribute :supportedSchema, namespace: :mod
            attribute :conformsTo, namespace: :mod
            attribute :catalog, namespace: :mod
            attribute :dataset, namespace: :mod
            attribute :service, namespace: :mod
            attribute :record, namespace: :mod
            attribute :themeTaxonomy, namespace: :mod
            attribute :distribution, namespace: :mod


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
            

            serialize_default :acronym, :title, :description, :logo, :fundedBy, :versionInfo, :homepage, :numberOfArtefacts, :federated_portals

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