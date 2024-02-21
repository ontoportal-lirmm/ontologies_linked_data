require_relative "../test_case"
require_relative './test_ontology_common'

class TestResource < LinkedData::TestOntologyCommon

  def self.before_suite
    LinkedData::TestCase.backend_4s_delete

    # Example
    data = %(
          <http://example.org/person1> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/Person> .
          <http://example.org/person1> <http://xmlns.com/foaf/0.1/name> "John Doe" .
          <http://example.org/person1> <http://xmlns.com/foaf/0.1/age> "30"^^<http://www.w3.org/2001/XMLSchema#integer> .
          <http://example.org/person1> <http://xmlns.com/foaf/0.1/gender> "male" .
          <http://example.org/person1> <http://xmlns.com/foaf/0.1/email> <mailto:john@example.com> .
          <http://example.org/person1> <http://xmlns.com/foaf/0.1/knows> _:blanknode1 .
          _:blanknode1 <http://xmlns.com/foaf/0.1/name> "Jane Smith" .
          _:blanknode1 <http://xmlns.com/foaf/0.1/age> "25"^^<http://www.w3.org/2001/XMLSchema#integer> .
          _:blanknode1 <http://xmlns.com/foaf/0.1/gender> "female" .
          _:blanknode1 <http://xmlns.com/foaf/0.1/email> <mailto:jane@example.com> .
          <http://example.org/person1> <http://xmlns.com/foaf/0.1/hasInterest> "Hiking" .
          <http://example.org/person1> <http://xmlns.com/foaf/0.1/hasInterest> "Cooking" .
          <http://example.org/person2> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/Person> .
          <http://example.org/person2> <http://xmlns.com/foaf/0.1/name> "Alice Cooper" .
          <http://example.org/person2> <http://xmlns.com/foaf/0.1/age> "35"^^<http://www.w3.org/2001/XMLSchema#integer> .
          <http://example.org/person2> <http://xmlns.com/foaf/0.1/gender> "female" .
          <http://example.org/person2> <http://xmlns.com/foaf/0.1/email> <mailto:alice@example.com> .
          <http://example.org/person2> <http://xmlns.com/foaf/0.1/hasSkill> _:skill1, _:skill2 .
          _:skill1 <http://www.w3.org/1999/02/22-rdf-syntax-ns#first> "Programming" .
          _:skill1 <http://www.w3.org/1999/02/22-rdf-syntax-ns#rest> _:skill2 .
          _:skill2 <http://www.w3.org/1999/02/22-rdf-syntax-ns#first> "Data Analysis" .
          _:skill2 <http://www.w3.org/1999/02/22-rdf-syntax-ns#rest> <http://www.w3.org/1999/02/22-rdf-syntax-ns#nil> .
          <http://example.org/person2> <http://xmlns.com/foaf/0.1/hasInterest> "Hiking" .
          <http://example.org/person2> <http://xmlns.com/foaf/0.1/hasInterest> "Cooking" .
          <http://example.org/person2> <http://xmlns.com/foaf/0.1/hasInterest> "Photography" .
        )
    # TODO test for attribute of type an array
    graph = "http://example.org/test_graph"
    Goo.sparql_data_client.execute_append_request(graph, data, '')

    # instance the resource model
    @@resource1 = LinkedData::Models::Resource.new("http://example.org/test_graph", "http://example.org/person1")
  end

  def self.after_suite
    Goo.sparql_data_client.delete_graph("http://example.org/test_graph")
    Goo.sparql_data_client.delete_graph("http://data.bioontology.org/ontologies/TEST-TRIPLES/submissions/2")
    @resource1&.destroy
  end


  def test_parsed_submission
    skip
    submission_parse('TEST-TRIPLES',
                     'TESTTRIPlES name of the ontology',
                     './test/data/ontology_files/efo_gwas.skos.owl', 2,
                     process_rdf: true, index_search: false,
                     run_metrics: false, reasoning: true
    )
    ont = LinkedData::Models::Ontology.find("TEST-TRIPLES").first
    sub = ont.latest_submission
    assert(!sub.id.empty?,"Failed submission TEST-TRIPLES")
  end

  def test_generate_model
    @object = @@resource1.to_object
        @model =  @object.class

    assert_equal LinkedData::Models::Base, @model.ancestors[1]

    @model.model_settings[:attributes].map do |property, val|
      property_url = "#{val[:property]}#{property}"
            assert_includes  @@resource1.to_hash.keys,  property_url
            

      hash_value = @@resource1.to_hash[property_url]
      object_value = @object.send(property.to_sym)

      assert_equal Array(hash_value).map(&:to_s), Array(object_value).map(&:to_s)
    end

    assert_equal "http://example.org/person1", @object.id.to_s

    assert_equal Goo.namespaces[:foaf][:Person].to_s, @model.type_uri.to_s
  end

  def test_resource_fetch_related_triples
    result = @@resource1.to_hash
    assert_instance_of Hash, result

    refute_empty result

    expected_result = { "id" => RDF::URI.new("http://example.org/person1"),
                        "http://www.w3.org/1999/02/22-rdf-syntax-ns#type" => "http://xmlns.com/foaf/0.1/Person",
                        "http://xmlns.com/foaf/0.1/gender" => "male",
                        "http://xmlns.com/foaf/0.1/age" => 30,
                        "http://xmlns.com/foaf/0.1/email" => "mailto:john@example.com", #"http://xmlns.com/foaf/0.1/knows"=>"1.9", #TODO to fix
                        "http://xmlns.com/foaf/0.1/name" => "John Doe",
                        "http://xmlns.com/foaf/0.1/hasInterest" => %w[Hiking Cooking],
    }

    result.each do |property_url, val|
      next if property_url.to_s.eql?('http://xmlns.com/foaf/0.1/knows') # TODO to fix

      if val.is_a?(Array)
        assert_equal val.map(&:to_s).sort, expected_result[property_url].map(&:to_s).sort
      else
        assert_equal val.to_s, expected_result[property_url].to_s
      end
    end
  end

  def test_resource_serialization_json
    skip
    result = @@resource1.to_json

    refute_empty result
    expected_result = %(
      {
        "@context": {
          "rdf": "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
          "foaf": "http://xmlns.com/foaf/0.1/"
        },
        "@id": "http://example.org/person1",
        "@type": "foaf:Person",
        "foaf:age": {
          "@type": "http://www.w3.org/2001/XMLSchema#integer",
          "@value": "30"
        },
        "foaf:email": {
          "@id": "mailto:john@example.com"
        },
        "foaf:gender": "male",
        "foaf:hasInterest": [
          "Hiking",
          "Cooking"
        ],
        "foaf:name": "JohnDoe"
      }
    )

    assert_equal expected_result, result
  end

  def test_resource_serialization_xml
    result = @@resource1.to_xml
    refute_empty result
    expected_result = %(
        <?xml version="1.0" encoding="UTF-8"?>
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" 
                 xmlns:foaf="http://xmlns.com/foaf/0.1/">

          <foaf:Person rdf:about="http://example.org/person1">
            <foaf:gender>male</foaf:gender>
            <foaf:hasInterest>Hiking</foaf:hasInterest>
            <foaf:hasInterest>Cooking</foaf:hasInterest>
            <foaf:age rdf:datatype="http://www.w3.org/2001/XMLSchema#integer">30</foaf:age>
            <foaf:email rdf:resource="mailto:john@example.com"/>
            <foaf:name>John Doe</foaf:name>
          </foaf:Person>
        </rdf:RDF>
      
    )

    a = result.gsub(' ', '').gsub("\n", '')
    b = expected_result.gsub(' ', '').gsub("\n", '')

    assert_equal b, a
  end

  def test_resource_serialization_ntriples
    result = @@resource1.to_ntriples

    refute_empty result

    expected_result = %(
          <http://example.org/person1> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/Person> .
          <http://example.org/person1> <http://xmlns.com/foaf/0.1/gender> "male" .
          <http://example.org/person1> <http://xmlns.com/foaf/0.1/hasInterest> "Hiking" .
          <http://example.org/person1> <http://xmlns.com/foaf/0.1/hasInterest> "Cooking" .
          <http://example.org/person1> <http://xmlns.com/foaf/0.1/age> "30"^^<http://www.w3.org/2001/XMLSchema#integer> .
          <http://example.org/person1> <http://xmlns.com/foaf/0.1/email> <mailto:john@example.com> .
          <http://example.org/person1> <http://xmlns.com/foaf/0.1/name> "JohnDoe" .
    )
    a = result.gsub(' ', '').gsub("\n", '')
    b = expected_result.gsub(' ', '').gsub("\n", '')

    assert_equal b, a
  end

  def test_resource_serialization_turtle
    result = @@resource1.to_turtle
    refute_empty result
    expected_result = %(
        @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
        @prefix foaf: <http://xmlns.com/foaf/0.1/> .
        
        <http://example.org/person1>
            a foaf:Person ;
            foaf:age "30" ;
            foaf:email <mailto:john@example.com> ;
            foaf:gender "male" ;
            foaf:hasInterest "Cooking", "Hiking" ;
            foaf:name "John Doe" .
              
    )
    a = result.gsub(' ', '').gsub("\n", '')
    b = expected_result.gsub(' ', '').gsub("\n", '')

    assert_equal b, a
  end

end