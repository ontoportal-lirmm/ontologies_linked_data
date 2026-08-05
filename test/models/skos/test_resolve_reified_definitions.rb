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

  # A concept of the same fixture carrying no definition at all: its only
  # resource valued properties are skos:broader, skos:inScheme and rdf:type.
  # None of them is a reified definition, so the step has to leave it alone.
  LINKED_CONCEPT = 'http://opendata.inrae.fr/thesaurusINRAE/c_0015b5e0'

  # What those links turn into when the definition properties of the queries do
  # not reach the backend: the labels of the broader concept, the labels of the
  # concept schemes, and - through rdf:type - the definition SKOS gives to
  # skos:Concept, which lands on every concept of the ontology at once.
  LEAKED_TEXTS = {
    'cell division' => 'skos:broader c_9399',
    'division cellulaire' => 'skos:broader c_9399',
    'BIO cell biology' => 'skos:inScheme mt_64',
    'Thésaurus INRAE' => 'skos:inScheme thesaurusINRAE',
    'An idea or notion; a unit of thought.' => 'rdf:type skos:Concept'
  }.freeze

  # Parsed with the step disabled, so everything the tests read afterwards can
  # only have come from the step. It runs once, here rather than inside a test:
  # minitest orders tests at random, so none of them may depend on being the one
  # that runs it.
  def self.before_suite
    LinkedData::TestCase.backend_4s_delete
    self.new('').submission_parse('INRAETHES', 'Testing skos',
                                  'test/data/ontology_files/thesaurusINRAE_nouv_structure.skos',
                                  1,
                                  process_rdf: true, extract_metadata: false, generate_missing_labels: false,
                                  resolve_reified_definitions: false)

    test = self.new('')
    sub = test.submission
    sub.bring_remaining # the step writes its triples next to the master file
    unless test.literal_definitions(sub, REIFIED_CONCEPT).empty?
      raise "#{REIFIED_CONCEPT} already carries a literal definition once parsed, " \
            'the assertions on the resolved text would prove nothing'
    end

    sub.resolve_reified_definitions(Logger.new(TestLogFile.new))
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
    sub.bring_remaining # the step writes its triples next to the master file
    sub.resolve_reified_definitions(Logger.new(TestLogFile.new))
    assert_equal 1, literal_definitions(sub, REIFIED_CONCEPT).length
  ensure
    RequestStore.store[:requested_lang] = nil
  end

  # The other half of the pattern: only the definition properties lead to a
  # reified definition. A concept whose resources are ordinary SKOS links keeps
  # no definition out of them - the labels sitting on a broader concept or on a
  # concept scheme are not its definition.
  #
  # This is what breaks first when the property restriction of the queries does
  # not reach the backend, and it breaks silently: every skos:broader,
  # skos:inScheme and rdf:type reads as a reified definition, the prefLabel of
  # its target reads as the text, and the step writes two orders of magnitude
  # more definitions than the ontology has.
  def test_ordinary_links_are_not_reified_definitions
    sub = submission

    assert_empty definition_objects(sub, LINKED_CONCEPT),
                 "#{LINKED_CONCEPT} has no definition in the fixture and gets none from the step"

    # Each text named with the link it would have come through, so a failure
    # says which one leaked rather than just counting definitions.
    resolved = literal_definitions(sub, LINKED_CONCEPT).map(&:value)
    LEAKED_TEXTS.each do |text, link|
      refute_includes resolved, text, "#{link} of #{LINKED_CONCEPT} is not a reified definition"
    end
  end

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
