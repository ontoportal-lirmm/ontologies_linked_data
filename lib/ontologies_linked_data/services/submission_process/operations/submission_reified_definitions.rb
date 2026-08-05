require 'benchmark'
require 'set'

module LinkedData
  module Services

    # Materialize the text carried by reified definition nodes as plain
    # skos:definition literals on the concept itself.
    #
    # Thesauri such as AGROVOC or the INRAE Thesaurus do not attach the
    # definition as a literal, they reify it onto a dedicated node:
    #
    #   <c_01cd9294>    skos:definition <note_a8fb2e24> .
    #   <note_a8fb2e24> rdf:value       "Pratique qui se definit..."@fr ;
    #                   dcterms:source  "Derivee de J. Boiffin..." .
    #
    # The definition then reaches the portal as a bare URI: nothing to display,
    # nothing to index, nothing to annotate. This step follows those nodes,
    # picks the predicate holding the text with a ranked list of heuristics
    # (rdf:value, skosxl:literalForm, ... down to skos:prefLabel/rdfs:label) and
    # asserts the text back on the concept as a skos:definition literal, keeping
    # the language tag.
    #
    # Nothing is removed: like every other step of the pipeline this one only
    # appends, so the submission graph stays a faithful copy of the source RDF
    # and the reified node keeps both its link and its provenance. A concept
    # therefore carries two definition objects afterwards - the node URI it
    # always had, and the text read out of it.
    class ResolveReifiedDefinitions < OntologySubmissionProcess

      # Concepts resolved per round trip to the triple store.
      PAGE_SIZE = 1_000

      # How many unresolved nodes are described in the log before only counting them.
      UNRESOLVED_SAMPLE = 25

      # Predicates able to carry the text of a reified definition, best first.
      # The first one present on a node wins and all of its literals are kept, so
      # a node holding the same text in several languages yields one definition
      # per language. Labels come last: on a node they are weak evidence, but a
      # label is still better than exposing a URI.
      TEXT_PREDICATES = [
        'http://www.w3.org/1999/02/22-rdf-syntax-ns#value',
        'http://www.w3.org/2008/05/skos-xl#literalForm',
        'http://www.w3.org/2004/02/skos/core#definition',
        'http://purl.obolibrary.org/obo/IAO_0000115',
        'http://purl.org/dc/terms/description',
        'http://purl.org/dc/elements/1.1/description',
        'http://www.w3.org/2000/01/rdf-schema#comment',
        'http://www.w3.org/2004/02/skos/core#scopeNote',
        'http://www.w3.org/2004/02/skos/core#note',
        'http://www.w3.org/2004/02/skos/core#prefLabel',
        'http://www.w3.org/2000/01/rdf-schema#label'
      ].freeze

      # Predicates that describe a definition instead of carrying it. They are
      # never used as text, not even by the last-resort single-candidate rule -
      # without this list a node holding only dcterms:source would turn its
      # bibliographic reference into the definition of the concept.
      PROVENANCE_PREDICATES = [
        'http://purl.org/dc/terms/source',
        'http://art.uniroma2.it/ontologies/vocbench#hasSource',
        'http://purl.org/dc/terms/created',
        'http://purl.org/dc/terms/modified',
        'http://purl.org/dc/terms/date',
        'http://purl.org/dc/terms/issued',
        'http://purl.org/dc/terms/creator',
        'http://purl.org/dc/terms/contributor',
        'http://purl.org/dc/terms/publisher',
        'http://purl.org/dc/terms/bibliographicCitation',
        'http://purl.org/dc/terms/identifier',
        'http://purl.org/dc/elements/1.1/source',
        'http://purl.org/dc/elements/1.1/creator',
        'http://purl.org/dc/elements/1.1/date',
        'http://purl.org/dc/elements/1.1/identifier',
        'http://www.w3.org/2004/02/skos/core#notation',
        'http://www.w3.org/2002/07/owl#versionInfo'
      ].freeze

      # Datatypes a definition text can be written with. Anything else on the
      # node (dates, counts, flags) is not definition text.
      TEXT_DATATYPES = [
        'http://www.w3.org/2001/XMLSchema#string',
        'http://www.w3.org/2001/XMLSchema#normalizedString',
        'http://www.w3.org/2001/XMLSchema#token',
        'http://www.w3.org/1999/02/22-rdf-syntax-ns#langString',
        'http://www.w3.org/1999/02/22-rdf-syntax-ns#PlainLiteral'
      ].freeze

      # The heuristics, kept free of any state so they can be exercised on their
      # own: the best ranked known predicate of the node, or - when the node uses
      # a vocabulary we do not know about - its single remaining candidate once
      # provenance is set aside. Anything more ambiguous is left alone rather
      # than guessed. Takes { predicate => [literal] }, returns the literals
      # holding the definition text (all of its languages).
      def self.definition_text(predicates)
        return [] if predicates.empty?

        best = TEXT_PREDICATES.find { |predicate| predicates.key?(predicate) }
        return predicates[best] if best

        candidates = predicates.reject { |predicate, _| PROVENANCE_PREDICATES.include?(predicate) }
        candidates.size == 1 ? candidates.values.first : []
      end

      def self.text_literal?(object)
        return false unless object.is_a?(RDF::Literal)
        return true if object.language

        object.datatype.nil? || TEXT_DATATYPES.include?(object.datatype.to_s)
      end

      # Assert the text the way the portal writes its own literals: language
      # tagged when the source is, a plain string otherwise - dropping any exotic
      # datatype the node used.
      def self.definition_literal(literal)
        return RDF::Literal.new(literal.value, language: literal.language) if literal.language

        RDF::Literal.new(literal.value, datatype: RDF::XSD.string)
      end

      def process(logger, options = {})
        resolve_reified_definitions(logger, options[:file_path])
        @submission
      rescue Exception => e
        # Enrichment must not sink the parsing: on failure the concepts simply
        # keep their reified definitions, unresolved. Exception, not
        # StandardError: Goo raises bare Exceptions out of the append path (its
        # rapper calls do), and this step runs before indexing - anything that
        # escapes here costs the submission its whole index.
        logger.error("Reified definitions resolution failed: #{e.class}: #{e.message}\n#{e.backtrace.join("\n\t")}")
        logger.flush
        @submission
      end

      private

      def resolve_reified_definitions(logger, file_path)
        properties = definition_properties
        save_in_file = file_path.nil? ? nil : File.join(File.dirname(file_path), 'definitions.ttl')
        stats = { scanned: 0, asserted: 0, unresolved: 0 }
        fsave = nil
        after = nil

        time = Benchmark.realtime do
          loop do
            concepts = reified_definition_concepts(properties, after)
            break if concepts.empty?

            triples = resolve_concepts(logger, properties, concepts, stats)
            stats[:scanned] += concepts.length

            unless triples.empty?
              data = triples.join("\n")
              fsave ||= File.open(save_in_file, 'w') if save_in_file
              fsave&.write(data + "\n")
              Goo.sparql_data_client.append_triples(@submission.id, data, mime_type = 'application/x-turtle')
              stats[:asserted] += triples.length
            end

            after = concepts.last
            break if concepts.length < PAGE_SIZE
          end
        end

        fsave&.close
        report(logger, stats, save_in_file, time)
      end

      def report(logger, stats, save_in_file, time)
        if stats[:scanned].zero?
          logger.info("No reified definition found in #{@submission.id.to_s}")
        else
          logger.info("Resolved #{stats[:asserted]} definitions out of the reified nodes of " \
                      "#{stats[:scanned]} concepts in #{time.round(2)} sec.")
          logger.info("Saved resolved definitions in #{save_in_file}") if save_in_file && stats[:asserted].positive?
        end

        if stats[:unresolved].positive?
          logger.info("#{stats[:unresolved]} reified nodes carry no recognizable definition text " \
                      'and were left as is')
        end
        logger.flush
      end

      # skos:definition plus the properties the portal treats as its equivalent,
      # so a reified definition is picked up whichever one the ontology uses.
      #
      # The queries below restrict on these with FILTER(?p IN (...)) rather than
      # a VALUES block: 4store parses VALUES and then silently ignores it, in
      # every position. That turns each pattern into an unrestricted one, and a
      # step meant to read a few hundred reified nodes instead walks every
      # skos:broader, skos:inScheme and rdf:type of every concept and asserts
      # the prefLabel it finds there as a definition.
      def definition_properties
        @submission.bring(:definitionProperty) if @submission.bring?(:definitionProperty)

        properties = [
          Goo.vocabulary(:skos)[:definition],
          LinkedData::Utils::Triples.obo_definition_standard,
          RDF::URI.new('http://purl.obolibrary.org/obo/def')
        ]
        properties << RDF::URI.new(@submission.definitionProperty.to_s) unless @submission.definitionProperty.nil?
        properties.uniq(&:to_s).map(&:to_ntriples)
      end

      # One page of concepts whose definition is a resource instead of a literal,
      # starting after the last concept of the previous page. A cursor rather
      # than an OFFSET: the literals this step asserts never match the pattern
      # below, but paging that survives a shrinking match set costs nothing here
      # and does not have to be revisited if that ever stops being true.
      def reified_definition_concepts(properties, after)
        filters = ["?definitionProperty IN (#{properties.join(', ')})", '!isLiteral(?node)']
        # IRIs order by their string value, so the cursor can compare on str().
        filters << "str(?concept) > #{RDF::Literal.new(after.to_s).to_ntriples}" if after

        query = <<~SPARQL
          SELECT DISTINCT ?concept
          FROM #{@submission.id.to_ntriples}
          WHERE {
            ?concept ?definitionProperty ?node .
            FILTER(#{filters.join(' && ')})
          }
          ORDER BY ?concept
          LIMIT #{PAGE_SIZE}
        SPARQL

        concepts = []
        Goo.sparql_query_client.query(query).each_solution { |sol| concepts << sol[:concept] }
        concepts
      end

      def resolve_concepts(logger, properties, concepts, stats)
        concept_list = concepts.map(&:to_ntriples).join(', ')
        existing = existing_definitions(properties, concept_list)
        triples = []

        definition_nodes(properties, concept_list).each do |concept, concept_nodes|
          concept_nodes.each do |node, predicates|
            literals = definition_text(predicates)

            if literals.empty?
              stats[:unresolved] += 1
              log_unresolved(logger, stats, concept, node, predicates)
              next
            end

            literals.each do |literal|
              # Skip a text the concept already carries as a literal, so nothing
              # is asserted twice when the source RDF says it both ways.
              next unless existing[concept].add?([literal.language.to_s.downcase, literal.value])

              triples << LinkedData::Utils::Triples.triple(RDF::URI.new(concept),
                                                           Goo.vocabulary(:skos)[:definition],
                                                           definition_literal(literal))
            end
          end
        end

        triples
      end

      # The literals hanging off the reified nodes of a page of concepts, as
      # { concept => { node => { predicate => [literal] } } }. Nodes carrying no
      # literal at all are kept (empty), they are the ones to report.
      def definition_nodes(properties, concept_list)
        query = <<~SPARQL
          SELECT ?concept ?node ?p ?o
          FROM #{@submission.id.to_ntriples}
          WHERE {
            ?concept ?definitionProperty ?node .
            FILTER(?concept IN (#{concept_list})
                   && ?definitionProperty IN (#{properties.join(', ')})
                   && !isLiteral(?node))
            OPTIONAL {
              ?node ?p ?o .
              FILTER(isLiteral(?o))
            }
          }
        SPARQL

        nodes = Hash.new { |h, k| h[k] = Hash.new { |h2, k2| h2[k2] = Hash.new { |h3, k3| h3[k3] = [] } } }
        Goo.sparql_query_client.query(query).each_solution do |sol|
          predicates = nodes[sol[:concept].to_s][sol[:node].to_s]
          next if sol[:p].nil?

          predicates[sol[:p].to_s] << sol[:o] if text_literal?(sol[:o])
        end
        nodes
      end

      # The definitions a page of concepts already holds as literals, so nothing
      # gets asserted twice.
      def existing_definitions(properties, concept_list)
        query = <<~SPARQL
          SELECT ?concept ?definition
          FROM #{@submission.id.to_ntriples}
          WHERE {
            ?concept ?definitionProperty ?definition .
            FILTER(?concept IN (#{concept_list})
                   && ?definitionProperty IN (#{properties.join(', ')})
                   && isLiteral(?definition))
          }
        SPARQL

        existing = Hash.new { |h, k| h[k] = Set.new }
        Goo.sparql_query_client.query(query).each_solution do |sol|
          existing[sol[:concept].to_s] << [sol[:definition].language.to_s.downcase, sol[:definition].value]
        end
        existing
      end

      def definition_text(predicates)
        self.class.definition_text(predicates)
      end

      def text_literal?(object)
        self.class.text_literal?(object)
      end

      def definition_literal(literal)
        self.class.definition_literal(literal)
      end

      def log_unresolved(logger, stats, concept, node, predicates)
        return if stats[:unresolved] > UNRESOLVED_SAMPLE

        described = predicates.keys.empty? ? 'no literal in this graph' : predicates.keys.join(', ')
        logger.info("No definition text on #{node}, reified definition of #{concept} (#{described})")
      end

    end
  end
end
