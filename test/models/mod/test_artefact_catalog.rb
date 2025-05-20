require_relative "../../test_case"
require_relative '../test_ontology_common'

class TestArtefactCatalog < LinkedData::TestOntologyCommon

  def self.before_suite
    backend_4s_delete
    self.new("before_suite").teardown
    catalog = LinkedData::Models::SemanticArtefactCatalog.new
    catalog.save
  end

  def self.after_suite
    self.new("before_suite").teardown
  end

  def test_create_artefact_catalog
    catalog = LinkedData::Models::SemanticArtefactCatalog.all.first
    assert_equal LinkedData::Models::SemanticArtefactCatalog , catalog.class
    catalog.bring(*LinkedData::Models::SemanticArtefactCatalog.goo_attrs_to_load([]))
    expected = {
      acronym: "OntoPortal",
      title: "OntoPortal",
      color: "#5499A3",
      description: "Welcome to OntoPortal Appliance, your ontology repository for your ontologies",
      status: "alpha",
      accessRights: "public",
      logo: "https://ontoportal.org/images/logo.png",
      license: "https://opensource.org/licenses/BSD-2-Clause",
      federated_portals: [
        "{:name=>\"agroportal\", :api=>\"http://data.agroportal.lirmm.fr\", :ui=>\"http://agroportal.lirmm.fr\", :apikey=>\"DUMMY_API_KEY_123456\", :color=>\"#3cb371\"}"
      ],
      fundedBy: [
        "{:img_src=>\"https://ontoportal.org/images/logo.png\", :url=>\"https://ontoportal.org/\"}"
      ],
      language: ["English"],
      keyword: [],
      bibliographicCitation: [],
      subject: [],
      coverage: [],
      createdWith: [],
      accrualMethod: [],
      accrualPeriodicity: [],
      wasGeneratedBy: [],
      contactPoint: [],
      creator: [],
      contributor: [],
      publisher: [],
      id: RDF::URI("http://data.bioontology.org/")
    }
    assert_equal expected, catalog.to_hash
    refute_nil catalog.numberOfArtefacts
  end

  def test_goo_attrs_to_load
      default_attrs = LinkedData::Models::SemanticArtefactCatalog.goo_attrs_to_load([])
      assert_equal [:acronym, :title, :color, :description, :logo, :identifier, :status, :language, :type, :accessRights, :license, :rightsHolder, 
      :landingPage, :keyword, :bibliographicCitation, :created, :modified, :contactPoint, :creator, :contributor, :publisher, :subject,
      :coverage, :createdWith, :accrualMethod, :accrualPeriodicity, :wasGeneratedBy, :accessURL, :numberOfArtefacts, :federated_portals, :fundedBy], default_attrs

      specified_attrs = LinkedData::Models::SemanticArtefactCatalog.goo_attrs_to_load([:acronym, :title, :keyword, :featureList])
      assert_equal [:acronym, :title, :keyword, :featureList], specified_attrs

      computed_attrs = [:modified, :numberOfArtefacts, :metrics, :numberOfClasses, :numberOfIndividuals, :numberOfProperties,
        :numberOfAxioms, :numberOfObjectProperties, :numberOfDataProperties, :numberOfLabels, :numberOfDeprecated,
        :numberOfUsingProjects, :numberOfEndorsements, :numberOfMappings, :numberOfUsers, :numberOfAgents]
      computed_attrs_bring = LinkedData::Models::SemanticArtefactCatalog.goo_attrs_to_load(computed_attrs)
      assert_equal computed_attrs, computed_attrs_bring
  end

  def test_bring_all_attrs
    sac = LinkedData::Models::SemanticArtefactCatalog.all.first
    all_attrs_to_bring = LinkedData::Models::SemanticArtefactCatalog.goo_attrs_to_load([:all])
    sac.bring(*all_attrs_to_bring)
    assert_equal all_attrs_to_bring.sort, (sac.loaded_attributes.to_a + [:type]).sort
  end
end