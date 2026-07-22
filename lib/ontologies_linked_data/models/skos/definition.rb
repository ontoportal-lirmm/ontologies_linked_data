module LinkedData
  module Models
    module SKOS
      # Reified SKOS definition node.
      #
      # Some ontologies (e.g. AGROVOC, INRAE Thesaurus) do not attach the
      # definition as a plain literal on `skos:definition`, but reify it onto a
      # dedicated node whose object carries the definition text plus provenance
      # (source, dates). The API used to return only the bare node URIs.
      #
      # Predicates observed in AgroPortal:
      #   text    -> rdf:value                     (language tagged)
      #   source  -> dcterms:source                (INRAE Thesaurus)
      #           -> vocbench:hasSource            (AGROVOC)
      #   created -> dcterms:created               (xsd:dateTime, when present)
      #   modified-> dcterms:modified              (when present)
      #
      # IMPORTANT: these reified nodes are NOT reliably typed. AGROVOC nodes have
      # no rdf:type at all, INRAE nodes are typed rdfs:Resource / owl:NamedIndividual
      # — never skos:Definition. A normal Goo model query constrains the subject
      # with `?id a <rdf_type>`, which would exclude every one of these nodes and
      # return empty objects. We therefore never load these nodes through the
      # standard typed query path: `Class#definitionXl` calls `reified` below,
      # which reads the node's predicates directly (no type constraint) and
      # returns plain, faithfully-built hashes. Nothing is synthesized: a field
      # appears only when the corresponding triple exists on the node, and any
      # predicate we do not name explicitly is preserved under `properties`.
      class Definition < LinkedData::Models::Base

        model :definition, name_with: :id, collection: :submission,
                           namespace: :skos,
                           rdf_type: ->(*x) { RDF::URI.new('http://www.w3.org/2004/02/skos/core#Definition') }

        attribute :value, namespace: :rdf
        attribute :source, namespace: :dcterms
        attribute :hasSource, namespace: :vocbench, property: :hasSource
        attribute :created, namespace: :dcterms
        attribute :modified, namespace: :dcterms
        attribute :submission, collection: ->(s) { s.resource_id }, namespace: :metadata

        serialize_never :submission, :id

        # RDF predicate -> serialized field name for the reified definition node.
        PREDICATE_MAP = {
          'http://www.w3.org/1999/02/22-rdf-syntax-ns#value' => 'value',
          'http://purl.org/dc/terms/source' => 'source',
          'http://art.uniroma2.it/ontologies/vocbench#hasSource' => 'hasSource',
          'http://purl.org/dc/terms/created' => 'created',
          'http://purl.org/dc/terms/modified' => 'modified'
        }.freeze

        # Resolve reified definition nodes (given by their URIs) into structured
        # objects, reading their predicates directly from the submission graph
        # without any rdf:type constraint. Returns an array of hashes in the same
        # order as `uris`; nodes with no triples are skipped.
        #
        # Language handling mirrors the rest of the API (Goo's language filter):
        # `requested_lang` comes from the request (`?lang=`/`?language=`), falls
        # back to the portal language, and `ALL` keeps every language. A node
        # whose definition text (rdf:value) is in a language other than the
        # requested one is dropped, so `?lang=fr` returns only the French
        # definitions; untagged text always matches.
        def self.reified(uris, submission, requested_lang: RequestStore.store[:requested_lang])
          uris = Array(uris).map { |u| RDF::URI.new(u.to_s) }
          return [] if uris.empty? || submission.nil?

          graph = submission.id
          values = uris.map { |u| "<#{u}>" }.join(' ')
          query = <<-SPARQL.strip
SELECT ?def ?p ?o WHERE {
  GRAPH <#{graph}> {
    VALUES ?def { #{values} }
    ?def ?p ?o .
  }
}
          SPARQL

          grouped = Hash.new { |h, k| h[k] = [] }
          Goo.sparql_query_client.query(query, query_options: { rules: :NONE }, graphs: [graph]).each do |sol|
            grouped[sol[:def].to_s] << [sol[:p].to_s, sol[:o]]
          end

          langs = requested_languages(requested_lang)
          uris.map { |uri| build(uri, grouped[uri.to_s], langs) }.compact
        end

        # Build one faithful hash from a node's (predicate, object) pairs, keeping
        # only the definition text that matches the requested language(s).
        def self.build(uri, predicates, langs = :ALL)
          return nil if predicates.nil? || predicates.empty?

          obj = { '@id' => uri.to_s, '@type' => type_uri.to_s }
          properties = Hash.new { |h, k| h[k] = [] }
          text_by_lang = {}

          predicates.each do |predicate, object|
            field = PREDICATE_MAP[predicate]
            case field
            when 'value'
              text_by_lang[object_language(object)] = literal_value(object)
            when nil
              properties[predicate] << object.to_s
            else
              # provenance (source / dates) - not language filtered
              obj[field] = literal_value(object)
            end
          end

          unless text_by_lang.empty?
            selected = select_language(text_by_lang, langs)
            return nil if selected.nil? # no text in the requested language

            if selected.is_a?(Hash) # one node carrying several languages (ALL)
              obj['value'] = selected
            else
              language, text = selected
              obj['value'] = text
              # Expose the language of this definition's text (like prefLabel's
              # per-language keys), so consumers can tell them apart under lang=all.
              obj['lang'] = language.to_s.downcase unless language == :none
            end
          end

          obj['properties'] = properties unless properties.empty?
          obj
        end

        def self.literal_value(object)
          object.is_a?(RDF::Literal) ? object.object : object.to_s
        end

        def self.object_language(object)
          return :none unless object.is_a?(RDF::Literal) && object.language

          object.language.to_s.upcase.to_sym
        end

        # Normalize the requested language into :ALL, or an array of upper-cased
        # language symbols (defaulting to the portal language). Mirrors Goo.
        def self.requested_languages(requested_lang)
          return :ALL if requested_lang.to_s.upcase == 'ALL'

          langs = requested_lang
          langs = Goo.portal_language if langs.nil? || (langs.respond_to?(:empty?) && langs.empty?)
          langs = langs.to_s.split(',') unless langs.is_a?(Array)
          langs.map { |l| l.to_s.upcase.to_sym }
        end

        # Pick the definition text for the requested language(s) from a
        # {language => text} map. Untagged text (:none) matches any request.
        # Returns a [language, text] pair, or (for a single node holding several
        # languages under lang=ALL) a {language => text} Hash, or nil when the
        # node has no text in the requested language.
        def self.select_language(text_by_lang, langs)
          if langs == :ALL
            return text_by_lang.first if text_by_lang.size == 1

            return text_by_lang.transform_keys { |l| l == :none ? '@none' : l.to_s.downcase }
          end

          match = text_by_lang.find { |lang, _| lang != :none && langs.include?(lang) }
          return match if match

          text_by_lang.key?(:none) ? [:none, text_by_lang[:none]] : nil
        end

      end
    end
  end

end
