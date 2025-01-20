require_relative "../../test_case"
require_relative '../test_ontology_common'

class TestArtefactDistribution < LinkedData::TestOntologyCommon

    def test_create_artefact_distribution
        create_test_ontology
        sa = LinkedData::Models::SemanticArtefact.find('STY')
        sa.ontology.bring(*:submissions)
        sad = LinkedData::Models::SemanticArtefactDistribution.new(sa.ontology.submissions[0])
        assert_equal LinkedData::Models::SemanticArtefactDistribution , sad.class
        assert_equal LinkedData::Models::Base, sad.class.ancestors[1]
        assert_equal "http://data.bioontology.org/artefacts/STY/distributions/1", sad.id.to_s
    end

    def test_goo_attrs_to_load
        attrs = LinkedData::Models::SemanticArtefactDistribution.goo_attrs_to_load([])
        assert_equal [:distributionId, :title, :deprecated, :hasRepresentationLanguage, :hasSyntax, :description, :created], attrs
    end

    def test_bring_attrs
        create_test_ontology
        sa = LinkedData::Models::SemanticArtefact.find('STY')
        sa.ontology.bring(*:submissions)
        sad = LinkedData::Models::SemanticArtefactDistribution.new(sa.ontology.submissions[0])
        assert_equal LinkedData::Models::Base, sad.class.ancestors[1]
        sad.bring(*LinkedData::Models::SemanticArtefactDistribution.goo_attrs_to_load([:all]))
    end

    private
    def create_test_ontology
        acr = "STY"
        init_test_ontology_msotest acr
    end
    
end