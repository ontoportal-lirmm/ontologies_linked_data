
module LinkedData
  module Models
    class ExternalClass
      include LinkedData::Hypermedia::Resource

      attr_reader :id, :ontology, :type_uri, :source, :self_link

      serialize_never :id, :ontology, :type_uri, :source, :self_link

      link_to LinkedData::Hypermedia::Link.new("self", lambda {|ec| ec.self_link.to_s}, "http://www.w3.org/2002/07/owl#Class"),
              LinkedData::Hypermedia::Link.new("ontology", lambda {|ec| ec.ontology.to_s}, Goo.vocabulary["Ontology"])

      def initialize(id, ontology, source)
        @id = id
        generate_ontology_uri(ontology, source)
        generate_self(id, source)
        @type_uri = RDF::URI.new("http://www.w3.org/2002/07/owl#Class")
        @source = source
      end

      def generate_ontology_uri(ontology, source)
        if source == "ext" && ontology.start_with?("http")
          @ontology = RDF::URI.new(CGI.unescape(ontology))
        else
          # LinkedData.settings.interportal_hash
          @ontology = "#{LinkedData.settings.interportal_hash[source]}/ontologies/#{ontology}"
        end
      end

      def generate_self(id, source)
        if source == "ext"
          @self_link = id
        else
          @self_link = "#{@ontology}/classes/#{CGI.escape(id)}"
        end
      end
    end
  end
end