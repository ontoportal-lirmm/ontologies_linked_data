require_relative "../../test_case"
require_relative '../test_ontology_common'

class TestArtefactCatalog < LinkedData::TestOntologyCommon

  def test_create_artefact_catalog
      sac = LinkedData::Models::SemanticArtefactCatalog.new
      assert_equal LinkedData::Models::SemanticArtefactCatalog , sac.class
      assert_equal "http://data.bioontology.org/", sac.id.to_s
  end

  def test_goo_attrs_to_load
      attrs = LinkedData::Models::SemanticArtefactCatalog.goo_attrs_to_load([])
      assert_equal [:acronym, :title, :description, :logo, :fundedBy, :versionInfo, :homepage, :numberOfArtefacts, :federated_portals], attrs
  end
  
end