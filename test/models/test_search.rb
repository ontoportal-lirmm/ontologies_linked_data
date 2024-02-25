require_relative '../test_case'

class TestSearch < LinkedData::TestCase


  def self.after_suite
    backend_4s_delete
    LinkedData::Models::Ontology.indexClear
    LinkedData::Models::Agent.indexClear
  end

  def setup
    self.class.after_suite
  end

  def test_search_ontology
    ont_count, ont_acronyms, created_ontologies = create_ontologies_and_submissions({
                                        process_submission: false,
                                        acronym: 'BROTEST',
                                        name: 'ontTEST Bla',
                                        file_path: '../../../../test/data/ontology_files/BRO_v3.2.owl',
                                        ont_count: 3,
                                        submission_count: 3
                                      })


    ontologies = LinkedData::Models::Ontology.search('*:*', {fq: 'resource_model: "ontology"'})['response']['docs']
    assert_equal 3, ontologies.size
    ontologies.each do |ont|
      select_ont = created_ontologies.select{|ont_created| ont_created.id.to_s.eql?(ont['id'])}.first
      refute_nil select_ont
      select_ont.bring_remaining
      assert_equal ont['name_text'], select_ont.name
      assert_equal ont['acronym_text'], select_ont.acronym
      assert_equal ont['viewingRestriction_t'], select_ont.viewingRestriction
      assert_equal ont['ontologyType_t'], select_ont.ontologyType.id
    end



    submissions = LinkedData::Models::Ontology.search('*:*', {fq: 'resource_model: "ontology_submission"'})['response']['docs']
    assert_equal 9, submissions.size

    submissions.each do |sub|
      created_sub = LinkedData::Models::OntologySubmission.find(RDF::URI.new(sub['id'])).first&.bring_remaining
      refute_nil created_sub
      assert_equal sub['description_text'], created_sub.description
      assert_equal sub['submissionId_i'], created_sub.submissionId
      assert_equal sub['URI_text'], created_sub.URI
      assert_equal sub['status_t'], created_sub.status
      assert_equal sub['deprecated_b'], created_sub.deprecated
      assert_equal sub['hasOntologyLanguage_t'], created_sub.hasOntologyLanguage.id.to_s
      assert_equal sub['released_dt'], created_sub.released.utc.strftime('%Y-%m-%dT%H:%M:%SZ')
      assert_equal sub['creationDate_dt'], created_sub.creationDate.utc.strftime('%Y-%m-%dT%H:%M:%SZ')
      assert_equal(sub['contact_txt'], created_sub.contact.map{ |x| x.bring_remaining.embedded_doc })
      assert_equal sub['dataDump_t'], created_sub.dataDump
      assert_equal sub['csvDump_t'], created_sub.csvDump
      assert_equal sub['uriLookupEndpoint_t'], created_sub.uriLookupEndpoint
      assert_equal sub['openSearchDescription_t'], created_sub.openSearchDescription
      assert_equal sub['endpoint_txt'], created_sub.endpoint
      assert_equal sub['uploadFilePath_t'], created_sub.uploadFilePath
      assert_equal sub['submissionStatus_txt'], created_sub.submissionStatus.map(&:id)
      embed_doc = created_sub.ontology.bring_remaining.embedded_doc
      embed_doc.each do |k,v|
        if v.is_a?(Array)
          assert_equal v, Array(sub["ontology_#{k}"])
        else
          assert_equal v, sub["ontology_#{k}"]
        end
      end
    end
  end

  def test_search_agents
    @@user1 = LinkedData::Models::User.new(:username => 'user111221', :email => 'some111221@email.org')
    @@user1.passwordHash = 'some random pass hash'
    @@user1.save

    @agents = [
      LinkedData::Models::Agent.new(name: 'name 0', email: 'test_0@test.com', agentType: 'organization', creator: @@user1),
      LinkedData::Models::Agent.new(name: 'name 1', email: 'test_1@test.com', agentType: 'organization', creator: @@user1),
      LinkedData::Models::Agent.new(name: 'name 2', email: 'test_2@test.com', agentType: 'person', creator: @@user1)
    ]
    @identifiers = [
      LinkedData::Models::AgentIdentifier.new(notation: '000h6jb29', schemaAgency: 'ROR', creator: @@user1),
      LinkedData::Models::AgentIdentifier.new(notation: '000h6jb29', schemaAgency: 'ORCID', creator: @@user1),
    ]

    @identifiers.each { |i| i.save }
    affiliations = @agents[0..1].map { |a| a.save }
    agent = @agents.last
    agent.affiliations = affiliations

    agent.identifiers = @identifiers
    agent.save


    agents = LinkedData::Models::Agent.search('*:*')['response']['docs']

    assert_equal 3, agents.size
    agents.each do |a|
      select_agent = @agents.select{|agent_created| agent_created.id.to_s.eql?(a['id'])}.first
      refute_nil select_agent
      select_agent.bring_remaining

      assert_equal a['name_text'], select_agent.name
      assert_equal a['email_text'], select_agent.email
      assert_equal a['agentType_t'], select_agent.agentType
      assert_equal(a['affiliations_txt'], select_agent.affiliations&.map{ |x| x.bring_remaining.embedded_doc })
      assert_equal(a['identifiers_texts'], select_agent.identifiers&.map{ |x| x.bring_remaining.embedded_doc })
      assert_equal a['creator_t'], select_agent.creator.bring_remaining.embedded_doc
    end

    @identifiers.each { |i| i.delete }
    @agents.each { |a| a.delete }
    @@user1.delete
  end

  def test_search_ontology_data
    ont_count, ont_acronyms, created_ontologies = create_ontologies_and_submissions({
                                                                                      process_submission: true,
                                                                                      process_options: {
                                                                                        process_rdf: true, extract_metadata: false,
                                                                                        generate_missing_labels: false,
                                                                                        index_search: false,
                                                                                      },
                                                                                      acronym: 'BROTEST',
                                                                                      name: 'ontTEST Bla',
                                                                                      file_path: 'test/data/ontology_files/thesaurusINRAE_nouv_structure.skos',
                                                                                      ont_count: 1,
                                                                                      submission_count: 1,
                                                                                      ontology_format: "SKOS"
                                                                                    })
    ont_sub = LinkedData::Models::Ontology.find("BROTEST-0").first
    ont_sub = ont_sub.latest_submission
    ont_sub.index_all_data(Logger.new($stdout))

    conn = Goo.search_client(:ontology_data)
    response = conn.search('*')

    count = Goo.sparql_query_client.query("SELECT  (COUNT( DISTINCT ?id) as ?c)  FROM <#{ont_sub.id}> WHERE {?id ?p ?v}")
               .first[:c]
               .to_i

    assert_equal count, response["response"]["numFound"]
  end
end
