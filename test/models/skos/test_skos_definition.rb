require_relative '../test_ontology_common'
require 'logger'

# Tests for reified skos:definition nodes exposed through Class#definitionXl.
#
# The INRAE Thesaurus fixture already contains a reified definition:
#   c_01cd9294 --skos:definition--> note_a8fb2e24
# where note_a8fb2e24 carries:
#   rdf:value    (fr text)
#   dct:source   (provenance, no date present)
#   rdf:type rdfs:Resource
# i.e. text + source but no created/modified date, which exercises the
# "expose only what is in the RDF" requirement. The node is NOT typed
# skos:Definition, so it is resolved with a type-free query, not a standard
# Goo model load.
class TestSkosDefinition < LinkedData::TestOntologyCommon

  REIFIED_CONCEPT = 'http://opendata.inrae.fr/thesaurusINRAE/c_01cd9294'
  REIFIED_NODE    = 'http://opendata.inrae.fr/thesaurusINRAE/note_a8fb2e24'
  EXPECTED_TEXT_START = "Pratique qui se définit comme l'ensemble des processus"
  EXPECTED_SOURCE_START = "Dérivée de J. Boiffin"
  RDF_VALUE = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#value'
  DCT_SOURCE = 'http://purl.org/dc/terms/source'
  RDF_TYPE = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type'
  RDFS_RESOURCE = 'http://www.w3.org/2000/01/rdf-schema#Resource'

  def self.before_suite
    LinkedData::TestCase.backend_4s_delete
    self.new('').submission_parse('INRAETHES', 'Testing skos',
                     'test/data/ontology_files/thesaurusINRAE_nouv_structure.skos',
                     1,
                     process_rdf: true, extract_metadata: false, generate_missing_labels: false)
  end

  def submission
    LinkedData::Models::Ontology.find('INRAETHES').first.latest_submission
  end

  # Backend-free: the predicate->field mapping is faithful and never synthesizes
  # missing provenance. A node with text + source but no dates must NOT produce
  # created/modified keys, and unmapped predicates land under `properties`.
  def test_build_maps_predicates_faithfully
    obj = LinkedData::Models::SKOS::Definition.build(
      RDF::URI.new(REIFIED_NODE),
      [
        [RDF_VALUE, RDF::Literal.new('Pratique qui se définit...', language: :fr)],
        [DCT_SOURCE, RDF::Literal.new('Dérivée de J. Boiffin...')],
        [RDF_TYPE, RDF::URI.new(RDFS_RESOURCE)]
      ]
    )

    assert_equal REIFIED_NODE, obj['@id']
    assert_equal 'http://www.w3.org/2004/02/skos/core#Definition', obj['@type']
    assert obj['value'].to_s.start_with?('Pratique')
    assert obj['source'].to_s.start_with?('Dérivée')
    refute obj.key?('created'), 'must not synthesize a created date'
    refute obj.key?('modified'), 'must not synthesize a modified date'
    refute obj.key?('hasSource'), 'must not synthesize a vocbench source'
    assert_equal [RDFS_RESOURCE], obj['properties'][RDF_TYPE]
  end

  # Backend-free: language selection mirrors the rest of the API. A specific
  # language keeps only matching (and untagged) definition text and drops nodes
  # in other languages; ALL keeps everything; untagged text always matches.
  def test_language_filtering
    d = LinkedData::Models::SKOS::Definition
    node = ->(lang) { [[RDF_VALUE, RDF::Literal.new("txt-#{lang}", language: lang)]] }

    fr = d.build(RDF::URI.new('http://x/fr'), node.call(:fr), d.requested_languages('fr'))
    assert_equal 'txt-fr', fr['value']
    assert_equal 'fr', fr['lang'], 'each definition exposes the language of its text'
    assert_nil d.build(RDF::URI.new('http://x/en'), node.call(:en), d.requested_languages('fr')),
               'a node whose text is in another language must be dropped'

    all = d.build(RDF::URI.new('http://x/fr'), node.call(:fr), d.requested_languages('ALL'))
    assert_equal 'txt-fr', all['value']
    assert_equal 'fr', all['lang']

    multi = [[RDF_VALUE, RDF::Literal.new('EN', language: :en)],
             [RDF_VALUE, RDF::Literal.new('FR', language: :fr)]]
    assert_equal 'FR', d.build(RDF::URI.new('http://x/m'), multi, d.requested_languages('fr'))['value']
    assert_equal({ 'en' => 'EN', 'fr' => 'FR' },
                 d.build(RDF::URI.new('http://x/m'), multi, d.requested_languages('ALL'))['value'])

    # untagged text matches any requested language and carries no lang key
    untagged = d.build(RDF::URI.new('http://x/u'), [[RDF_VALUE, RDF::Literal.new('plain')]],
                       d.requested_languages('fr'))
    assert_equal 'plain', untagged['value']
    refute untagged.key?('lang')
  end

  # A concept whose skos:definition object is a resource gets the node resolved
  # into a structured object, while the flat `definition` attribute is unchanged.
  def test_class_reified_definition_resolved
    cls = LinkedData::Models::Class.find(REIFIED_CONCEPT)
                                   .in(submission)
                                   .include(:prefLabel, :definition)
                                   .first
    refute_nil cls

    # Back-compat: the flat attribute still exposes the raw skos:definition
    # object (here the bare reified node URI).
    assert_equal [REIFIED_NODE], cls.definition.map(&:to_s)

    # The node's text is French; request it (default portal language would
    # filter it out, mirroring the rest of the API).
    RequestStore.store[:requested_lang] = :FR
    defs = cls.definitionXl
    assert_equal 1, defs.size
    definition = defs.first
    assert_equal REIFIED_NODE, definition['@id']
    assert definition['value'].to_s.start_with?(EXPECTED_TEXT_START)
    assert definition['source'].to_s.start_with?(EXPECTED_SOURCE_START)
    # Faithful: this node has a source but no date in the RDF.
    refute definition.key?('created')
    refute definition.key?('modified')
  ensure
    RequestStore.store[:requested_lang] = nil
  end

  # Back-compat: a concept whose skos:definition object is a plain literal keeps
  # `definition` as strings, and definitionXl is empty (no reified nodes).
  def test_class_literal_definition_back_compat
    literal_concept = find_class_with_literal_definition
    skip 'No class with a plain-literal definition in fixture' if literal_concept.nil?

    cls = LinkedData::Models::Class.find(literal_concept.to_s)
                                   .in(submission)
                                   .include(:definition)
                                   .first
    refute_nil cls

    refute_empty cls.definition
    cls.definition.each { |d| refute d.is_a?(RDF::URI), 'literal definition must not be a URI' }
    assert_empty cls.definitionXl
  end

  private

  # Find any loaded class whose skos:definition is a plain literal (object is
  # not a resource) so we can assert the literal path is unchanged.
  def find_class_with_literal_definition
    sub = submission
    query = <<~SPARQL
      SELECT DISTINCT ?id WHERE {
        GRAPH <#{sub.id}> {
          ?id <http://www.w3.org/2004/02/skos/core#definition> ?def .
          ?id a <http://www.w3.org/2004/02/skos/core#Concept> .
          FILTER(isLiteral(?def))
        }
      } LIMIT 1
    SPARQL
    Goo.sparql_query_client.query(query).each do |sol|
      return sol[:id]
    end
    nil
  end
end
