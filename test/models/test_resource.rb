require_relative "../test_case"
require_relative './test_ontology_common'

class TestResource < LinkedData::TestOntologyCommon

    def self.before_suite
        LinkedData::TestCase.backend_4s_delete
        
        # Example
        data = %(
            @prefix ex: <http://example.org/> .
            @prefix rdf: <#{Goo.vocabulary(:rdf)}> .
            @prefix owl: <#{Goo.vocabulary(:owl)}> .
            @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

            ex:TestSubject1 rdf:type owl:Ontology .
            ex:TestSubject1 ex:TestPredicate11 "TestObject11" .
            ex:TestSubject1 ex:TestPredicate12 ex:test .
            ex:TestSubject1 ex:TestPredicate13 1 .
            ex:TestSubject1 ex:TestPredicate14 true .
            ex:TestSubject1 ex:TestPredicate15 "1.9"^^xsd:float .
            ex:TestSubject2 ex:TestPredicate2 1.9 .
        )
        # TODO test for attribute of type an array 
        graph = "http://example.org/test_graph"
        Goo.sparql_data_client.execute_append_request(graph, data, "application/x-turtle")
        
        # instance the resource model
        @@resource1 = LinkedData::Models::Resource.new("http://example.org/test_graph","http://example.org/TestSubject1")
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

        
            assert_equal hash_value, object_value
        end
 
        assert_equal "http://example.org/TestSubject1", @object.id.to_s 
  
        assert_equal Goo.namespaces[:owl][:Ontology].to_s , @model.type_uri.to_s 
    end

    def test_resource_fetch_related_triples
        result = @@resource1.to_hash
        assert_instance_of Hash, result
    

        refute_empty result 

        expected_result =  {"id"=>"http://example.org/TestSubject1",
        "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"=>"http://www.w3.org/2002/07/owl#Ontology",
        "http://example.org/TestPredicate12"=>"http://example.org/test",
        "http://example.org/TestPredicate14"=>"true",
        "http://example.org/TestPredicate13"=>"1",
        "http://example.org/TestPredicate15"=>"1.9",
        "http://example.org/TestPredicate11"=>"TestObject11"}
   
        result.each do |property_url, val|
            assert_equal val.to_s, expected_result[property_url]
        end 
    end

    def test_resource_serialization_json
        skip
        result = @@resource1.to_json
        
        refute_empty result
        expected_result = %(
           {
            @context: {
                TestPredicate11: "http://example.org/TestPredicate11",
                TestPredicate12: "http://example.org/TestPredicate12",
                TestPredicate13: "http://example.org/TestPredicate13",
                TestPredicate14: "http://example.org/TestPredicate14",
                TestPredicate15: "http://example.org/TestPredicate15",
            }, 
            @id: "http://example.org/TestSubject1", 
            @type: "http://www.w3.org/2002/07/owl#Ontology", 
            TestPredicate12: "http://example.org/test", 
            TestPredicate14: true, 
            TestPredicate13: 1, 
            TestPredicate15: 1.9,
            TestPredicate11: "TestObject11"
            }
        )
        assert_equal expected_result, result
    end

    def test_resource_serialization_xml
        #skip
        result = @@resource1.to_xml
        refute_empty result 
        expected_result = %(
            <?xml version="1.0" encoding="utf-8"?>
            <rdf:RDF
                xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                xmlns:owl="http://www.w3.org/2002/07/owl#"
                xmlns:xsd="http://www.w3.org/2001/XMLSchema#"
                xmlns:ex="http://example.org/">
            
                <rdf:Description rdf:about="http://example.org/TestSubject1">
                    <rdf:type rdf:resource="http://www.w3.org/2002/07/owl#Ontology"/>
                    <ex:TestPredicate11>TestObject11</ex:TestPredicate11>
                    <ex:TestPredicate12 rdf:resource="http://example.org/test"/>
                    <ex:TestPredicate13 rdf:datatype="http://www.w3.org/2001/XMLSchema#integer">1</ex:TestPredicate13>
                    <ex:TestPredicate14 rdf:datatype="http://www.w3.org/2001/XMLSchema#boolean">true</ex:TestPredicate14>
                    <ex:TestPredicate15 rdf:datatype="http://www.w3.org/2001/XMLSchema#float">1.9</ex:TestPredicate15>
                </rdf:Description>
            </rdf:RDF>
        )
        #binding.pry

        assert_equal expected_result, result
    end

    def test_resource_serialization_ntriples
        result = @@resource1.to_ntriples

        refute_empty result

        expected_result = %(
            <http://example.org/TestSubject1> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/2002/07/owl#Ontology> .
            <http://example.org/TestSubject1> <http://example.org/TestPredicate12> <http://example.org/test> .
            <http://example.org/TestSubject1> <http://example.org/TestPredicate14> "true"^^<http://www.w3.org/2001/XMLSchema#boolean> .
            <http://example.org/TestSubject1> <http://example.org/TestPredicate13> "1"^^<http://www.w3.org/2001/XMLSchema#integer> .
            <http://example.org/TestSubject1> <http://example.org/TestPredicate15> "1.9"^^<http://www.w3.org/2001/XMLSchema#float> .
            <http://example.org/TestSubject1> <http://example.org/TestPredicate11> "TestObject11" .
        )
        a = result.gsub(' ', '').gsub("\n",'')
        b = expected_result.gsub(' ', '').gsub("\n",'')
        
        assert_equal b, a 
    end


    def test_resource_serialization_turtle
        result = @@resource1.to_turtle
        refute_empty result
        expected_result = %(
            @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
            @prefix owl: <http://www.w3.org/2002/07/owl#> .
            
            <http://example.org/TestSubject1> a owl:Ontology ;
                <http://example.org/TestPredicate12> <http://example.org/test> ;
                <http://example.org/TestPredicate14> true ;
                <http://example.org/TestPredicate13> 1 ;
                <http://example.org/TestPredicate15> "1.9"^^<http://www.w3.org/2001/XMLSchema#float> ;
                <http://example.org/TestPredicate11> "TestObject11" .
            
        )

        assert_equal expected_result, result
    end

end