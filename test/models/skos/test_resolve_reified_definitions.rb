require_relative '../test_ontology_common'
require 'logger'

# Tests for ResolveReifiedDefinitions, the processing step that turns a reified
# definition into a plain skos:definition literal on the concept.
#
# The INRAE Thesaurus fixture carries the canonical shape:
#   c_01cd9294 --skos:definition--> note_a8fb2e24
#   note_a8fb2e24  rdf:value  "Pratique qui se définit..."@fr
#                  dct:source "Dérivée de J. Boiffin..."
# so it exercises both halves of the heuristics: rdf:value is picked as the
# text, dcterms:source is provenance and must never become a definition.
class TestResolveReifiedDefinitions < LinkedData::TestOntologyCommon

  RESOLVER = LinkedData::Services::ResolveReifiedDefinitions

  REIFIED_CONCEPT = 'http://opendata.inrae.fr/thesaurusINRAE/c_01cd9294'
  REIFIED_NODE    = 'http://opendata.inrae.fr/thesaurusINRAE/note_a8fb2e24'
  EXPECTED_TEXT_START = "Pratique qui se définit comme l'ensemble des processus"
  EXPECTED_SOURCE_START = 'Dérivée de J. Boiffin'
  SKOS_DEFINITION = 'http://www.w3.org/2004/02/skos/core#definition'
  RDF_VALUE = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#value'
  DCT_SOURCE = 'http://purl.org/dc/terms/source'
  SKOS_PREFLABEL = 'http://www.w3.org/2004/02/skos/core#prefLabel'

  # Parsed with the step disabled: the test drives it explicitly so it can
  # observe the graph before, after, and after a second run.
  def self.before_suite
    LinkedData::TestCase.backend_4s_delete
    self.new('').submission_parse('INRAETHES', 'Testing skos',
                                  'test/data/ontology_files/thesaurusINRAE_nouv_structure.skos',
                                  1,
                                  process_rdf: true, extract_metadata: false, generate_missing_labels: false,
                                  resolve_reified_definitions: false)
  end

  def submission
    LinkedData::Models::Ontology.find('INRAETHES').first.latest_submission
  end

  # Backend-free: rdf:value wins over the provenance sitting next to it, and all
  # of its languages are kept.
  def test_text_predicate_ranking
    text_fr = RDF::Literal.new('texte', language: :fr)
    text_en = RDF::Literal.new('text', language: :en)
    source = RDF::Literal.new('Boiffin, 2020')

    literals = RESOLVER.definition_text({ RDF_VALUE => [text_fr, text_en], DCT_SOURCE => [source] })
    assert_equal %w[texte text], literals.map(&:value), 'rdf:value carries the text, in every language'

    # A lower ranked predicate is only used when no better one is on the node.
    label_only = RESOLVER.definition_text({ SKOS_PREFLABEL => [text_fr] })
    assert_equal ['texte'], label_only.map(&:value)

    both = RESOLVER.definition_text({ SKOS_PREFLABEL => [text_en], RDF_VALUE => [text_fr] })
    assert_equal ['texte'], both.map(&:value), 'rdf:value outranks a label'
  end

  # Backend-free: provenance alone is never turned into a definition, and an
  # unknown node too ambiguous to read is left alone rather than guessed.
  def test_provenance_is_never_a_definition
    assert_empty RESOLVER.definition_text({ DCT_SOURCE => [RDF::Literal.new('Boiffin, 2020')] })
    assert_empty RESOLVER.definition_text({})

    unknown = 'http://example.org/note'
    other = 'http://example.org/comment'
    assert_equal ['texte'],
                 RESOLVER.definition_text({ unknown => [RDF::Literal.new('texte')],
                                            DCT_SOURCE => [RDF::Literal.new('Boiffin, 2020')] }).map(&:value),
                 'a single candidate left after provenance is the definition'
    assert_empty RESOLVER.definition_text({ unknown => [RDF::Literal.new('a')], other => [RDF::Literal.new('b')] }),
                 'two unknown candidates are ambiguous, nothing is guessed'
  end

  # Backend-free: only text-shaped literals are candidates, and what gets
  # asserted keeps the language while dropping exotic datatypes.
  def test_literal_handling
    assert RESOLVER.text_literal?(RDF::Literal.new('texte', language: :fr))
    assert RESOLVER.text_literal?(RDF::Literal.new('texte'))
    refute RESOLVER.text_literal?(RDF::Literal.new(DateTime.now)), 'a date is not definition text'
    refute RESOLVER.text_literal?(RDF::Literal.new(42))
    refute RESOLVER.text_literal?(RDF::URI.new(REIFIED_NODE))

    tagged = RESOLVER.definition_literal(RDF::Literal.new('texte', language: :fr))
    assert_equal 'texte', tagged.value
    assert_equal :fr, tagged.language

    exotic = RESOLVER.definition_literal(RDF::Literal.new('texte', datatype: RDF::XSD.token))
    assert_equal 'texte', exotic.value
    assert_equal RDF::XSD.string, exotic.datatype
  end

  # The whole step against the triple store: a reified definition becomes a
  # literal on the concept, nothing is removed from the graph, the provenance is
  # not mistaken for the text, and replaying the step does not duplicate
  # anything.
  def test_resolve_reified_definitions
    sub = submission
    sub.bring_remaining # the step writes its triples next to the master file
    assert_empty literal_definitions(sub, REIFIED_CONCEPT),
                 'the fixture concept starts with no literal definition'

    sub.resolve_reified_definitions(Logger.new(TestLogFile.new))

    definitions = literal_definitions(sub, REIFIED_CONCEPT)
    assert_equal 1, definitions.length
    definition = definitions.first
    assert definition.value.start_with?(EXPECTED_TEXT_START)
    assert_equal :fr, definition.language, 'the language of the reified text is kept'
    refute definition.value.start_with?(EXPECTED_SOURCE_START), 'dcterms:source is not the definition'

    # The step only appends: the reified triple and the node it points at are
    # both still there.
    assert_includes definition_objects(sub, REIFIED_CONCEPT).map(&:to_s), REIFIED_NODE
    assert node_still_described?(sub, REIFIED_NODE)

    # The attribute reports the graph as it is: the text the step resolved, and
    # the node URI the ontology put there, side by side.
    RequestStore.store[:requested_lang] = :FR
    cls = LinkedData::Models::Class.find(REIFIED_CONCEPT).in(sub).include(:definition).first
    values = cls.definition.map(&:to_s)
    assert values.any? { |value| value.start_with?(EXPECTED_TEXT_START) },
           'the concept exposes the resolved text through its definition'
    assert_includes values, REIFIED_NODE, 'the node URI is left where the ontology put it'

    # Replayed on an already enriched graph, the step adds nothing.
    sub.resolve_reified_definitions(Logger.new(TestLogFile.new))
    assert_equal 1, literal_definitions(sub, REIFIED_CONCEPT).length
  ensure
    RequestStore.store[:requested_lang] = nil
  end

  private

  def definition_objects(sub, concept)
    query = <<~SPARQL
      SELECT ?definition
      FROM <#{sub.id}>
      WHERE { <#{concept}> <#{SKOS_DEFINITION}> ?definition . }
    SPARQL
    objects = []
    Goo.sparql_query_client.query(query).each_solution { |sol| objects << sol[:definition] }
    objects
  end

  def literal_definitions(sub, concept)
    definition_objects(sub, concept).select { |o| o.is_a?(RDF::Literal) }
  end

  def node_still_described?(sub, node)
    query = <<~SPARQL
      SELECT ?p FROM <#{sub.id}> WHERE { <#{node}> ?p ?o . } LIMIT 1
    SPARQL
    described = false
    Goo.sparql_query_client.query(query).each_solution { described = true }
    described
  end
end
