require_relative "../../test_case"
require_relative '../test_ontology_common'

class TestArtefact < LinkedData::TestOntologyCommon

    def test_create_artefact
        sa = LinkedData::Models::SemanticArtefact.new
        assert_equal LinkedData::Models::SemanticArtefact , sa.class
    end

    def test_find_artefact
        create_test_ontology
        sa = LinkedData::Models::SemanticArtefact.find('STY')
        assert_equal LinkedData::Models::SemanticArtefact , sa.class
        assert_equal "STY", sa.acronym
        assert_equal "STY", sa.ontology.acronym
    end


    def test_goo_attrs_to_load
        attrs = LinkedData::Models::SemanticArtefact.goo_attrs_to_load([])
        assert_equal [:acronym, :accessRights, :subject, :URI, :versionIRI, :creator, :identifier, :status, :language, 
        :license, :rightsHolder, :description, :landingPage, :keyword, :bibliographicCitation, :contactPoint,
        :contributor, :publisher, :coverage, :createdWith, :accrualMethod, :accrualPeriodicity, 
        :competencyQuestion, :wasGeneratedBy, :hasFormat, :includedInDataCatalog, :semanticArtefactRelation], attrs
    end

    def test_bring_attrs
        create_test_ontology
        r = LinkedData::Models::SemanticArtefact.find('STY')
        r.bring(*LinkedData::Models::SemanticArtefact.goo_attrs_to_load([:all]))
        ont = r.ontology
        latest_sub = r.ontology.latest_submission
        latest_sub.bring(*LinkedData::Models::OntologySubmission.goo_attrs_to_load([:all]))

        LinkedData::Models::SemanticArtefact.attribute_mappings.each do |artefact_key, mapping|
            value_artefact_attr = r.send(artefact_key)
            mapped_attr = mapping[:attribute]

            case mapping[:model]
            when :ontology
                value_ontology_attr = ont.send(mapped_attr)
                if value_ontology_attr.is_a?(Array)
                    value_artefact_attr.each_with_index do |v, i|
                        assert_equal v.id, value_ontology_attr[i].id
                    end
                else
                    assert_equal value_artefact_attr, value_ontology_attr
                end
            when :ontology_submission
                value_submission_attr = latest_sub.send(mapped_attr)

                if value_submission_attr.is_a?(Array)
                    value_artefact_attr.each_with_index do |v, i|
                        assert_equal v.id, value_submission_attr[i].id
                    end
                else
                    assert_equal value_artefact_attr, value_submission_attr
                end
            end
        end

        assert_equal r.analytics, ont.analytics
    end


    def test_latest_distribution
        create_test_ontology
        sa = LinkedData::Models::SemanticArtefact.find('STY')
        assert_equal "STY", sa.acronym
        latest_distribution = sa.latest_distribution(status: :any)

        assert_equal LinkedData::Models::SemanticArtefactDistribution , latest_distribution.class
        assert_equal 1, latest_distribution.distributionId
        assert_equal 1, latest_distribution.submission.submissionId
    end
    
    def test_distributions
        create_test_ontology
        r = LinkedData::Models::SemanticArtefact.find('STY')
        options = {
            status: "ANY",
            includes: LinkedData::Models::SemanticArtefactDistribution.goo_attrs_to_load([])
        }
        all_distros = r.all_distributions(options)

        assert_equal Array, all_distros.class
        assert_equal 1, all_distros.length
        assert_equal 1, all_distros.length
        assert_equal LinkedData::Models::SemanticArtefactDistribution, all_distros[0].class
        assert_equal Set[:distributionId, :title, :hasRepresentationLanguage, :hasSyntax, :description, :created, :modified, :conformsToKnowledgeRepresentationParadigm, :usedEngineeringMethodology, :prefLabelProperty, :synonymProperty, :definitionProperty, :accessURL, :downloadURL], all_distros[0].loaded_attributes
    end
    
    private
    def create_test_ontology
        acr = "STY"
        init_test_ontology_msotest acr
    end
end