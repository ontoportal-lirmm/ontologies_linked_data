require_relative "../../test_case"
require_relative '../test_ontology_common'

class TestArtefactCatalog < LinkedData::TestOntologyCommon

  def test_create_artefact_catalog
      sac = LinkedData::Models::SemanticArtefactCatalog.new
      assert_equal LinkedData::Models::SemanticArtefactCatalog , sac.class
      assert_equal "http://data.bioontology.org/", sac.id.to_s
  end

  def test_goo_attrs_to_load
      all_attrs = LinkedData::Models::SemanticArtefactCatalog.goo_attrs_to_load([:all])
      assert_equal LinkedData::Models::SemanticArtefactCatalog.attributes(:all), all_attrs

      default_attrs = LinkedData::Models::SemanticArtefactCatalog.goo_attrs_to_load([])
      assert_equal [:acronym, :title, :color, :description, :logo, :fundedBy, :versionInfo, :homepage, :numberOfArtefacts, :federated_portals], default_attrs

      specified_attrs = LinkedData::Models::SemanticArtefactCatalog.goo_attrs_to_load([:acronym, :title, :keyword, :featureList])
      assert_equal [:acronym, :title, :keyword, :featureList], specified_attrs

      computed_attrs = [:modified, :numberOfArtefacts, :metrics, :numberOfClasses, :numberOfIndividuals, :numberOfProperties,
        :numberOfAxioms, :numberOfObjectProperties, :numberOfDataProperties, :numberOfLabels, :numberOfDeprecated,
        :numberOfUsingProjects, :numberOfEndorsements, :numberOfMappings, :numberOfUsers, :numberOfAgents]
      computed_attrs_bring = LinkedData::Models::SemanticArtefactCatalog.goo_attrs_to_load(computed_attrs)
      assert_equal computed_attrs, computed_attrs_bring
  end

  def test_bring_attrs
    sac = LinkedData::Models::SemanticArtefactCatalog.new
    assert_equal true, sac.valid?
    sac.send("acronym=", "ontoportal")
    sac.save
    all_attrs_to_bring = LinkedData::Models::SemanticArtefactCatalog.goo_attrs_to_load([:all])
    sac.bring(*all_attrs_to_bring)
    assert_equal all_attrs_to_bring, sac.loaded_attributes.to_a
  end
end