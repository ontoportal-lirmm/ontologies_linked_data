require_relative './identifier'

module LinkedData
  module Models
    # An agent (eg. person, group, software or physical artifact)
    class Agent < LinkedData::Models::Base

      model :Agent, namespace: :foaf, name_with: lambda { |cc| uuid_uri_generator(cc) }
      attribute :agentType, enforce: [:existence], enforcedValues: %w[person organization]
      attribute :name, namespace: :foaf, enforce: %i[existence], fuzzy_search: true

      attribute :homepage, namespace: :foaf
      attribute :acronym, namespace: :skos, property: :altLabel, fuzzy_search: true
      attribute :email, namespace: :foaf, property: :mbox, enforce: %i[email unique], fuzzy_search: true

      attribute :identifiers, namespace: :adms, property: :identifier, enforce: %i[Identifier list unique_identifiers], fuzzy_search: true
      attribute :affiliations, enforce: %i[Agent list is_organization], namespace: :org, property: :memberOf
      attribute :creator, type: :user, enforce: [:existence]
      embed :identifiers, :affiliations
      serialize_methods :usages, :keywords, :groups, :categories, :relatedAgents, :affiliatedAgents
      embed_values affiliations: [:name, :agentType, :homepage, :acronym, :email, :identifiers]

      prevent_serialize_when_nested :usages, :affiliations, :keywords, :groups, :categories, :relatedAgents, :affiliatedAgents
          
      write_access :creator
      access_control_load :creator

      enable_indexing(:agents_metadata)

      def embedded_doc
        {
          "id": "#{self.id}",
          "name": "#{self.name}",
          "acronym": "#{self.acronym}",
          "email": "#{self.email}",
          "agentType": "#{self.agentType}"
        }.to_json
      end

      def self.load_agents_usages(agents = [], agent_attributes =  OntologySubmission.agents_attr_uris)
        q = Goo.sparql_query_client.select(:id, :property, :agent, :status).distinct.from(LinkedData::Models::OntologySubmission.uri_type).where([:id,LinkedData::Models::OntologySubmission.attribute_uri(:submissionStatus),:status], [:id, :property, :agent])
        q = q.filter("?status = <#{RDF::URI.new(LinkedData::Models::SubmissionStatus.id_prefix + 'RDF')}> || ?status = <#{RDF::URI.new(LinkedData::Models::SubmissionStatus.id_prefix + 'UPLOADED')}>")
        q = q.filter(agent_attributes.map{|attr| "?property = <#{attr}>"}.join(' || '))
        q = q.values(:agent,  *agents.map { |agent| RDF::URI(agent.id.to_s)})

        data = q.each_solution.group_by{|x| x[:agent]}

        agents_usages = data.transform_values do |values|
          r = values.select { |value| value[:status]['RDF'] }
          r = values.select { |value| value[:status]['UPLOADED'] } if r.empty?
          r.reject{|x| x[:property].nil? }.map{|x| [x[:id], x[:property]]}
        end

        agents.each do |agent|
          usages = agents_usages[agent.id]
          usages = usages ? usages.group_by(&:shift) : {}
          usages = usages.transform_values{|x| x.flatten.map(&:to_s)}

          agent.instance_variable_set("@usages", usages)
          agent.loaded_attributes.add(:usages)
        end
      end

      def usages(force_update: false)
        self.class.load_agents_usages([self]) if  !instance_variable_defined?("@usages")  || force_update
        @usages
      end

      def self.load_agents_keywords(agent)
        q = Goo.sparql_query_client.select(:keywords).distinct.from(LinkedData::Models::OntologySubmission.uri_type).where([:id, :property, :agent], [:id, LinkedData::Models::OntologySubmission.attribute_uri(:keywords), :keywords])
        q = q.filter("?agent = <#{agent.id}>")
        q = q.values(:id,  *agent.usages.keys.map { |uri| RDF::URI(uri.to_s)})


        keywords = q.solutions.map { |solution| solution[:keywords].to_s }
        agent.instance_variable_set("@keywords", keywords)
        agent.loaded_attributes.add(:keywords)
      end
      def keywords(force_update: false)
        self.class.load_agents_keywords(self) if  !instance_variable_defined?("@keywords")  || force_update
        @keywords
      end
      
      def self.load_agents_categories(agent)
        if agent.usages.empty?
          categories = []
        else
          uris = agent.class.strip_submission_id_from_uris(agent.usages.keys)
                    
          q = Goo.sparql_query_client.select(:categories).distinct.from(LinkedData::Models::Ontology.uri_type)
          q = q.optional([:id, LinkedData::Models::Ontology.attribute_uri(:hasDomain), :categories])
          q = q.values(:id, *uris)
          
          categories = q.solutions.map { |solution| solution[:categories] || solution["categories"] }.compact.uniq.reject(&:empty?)
        end
        agent.instance_variable_set("@categories", categories)
        agent.loaded_attributes.add("categories")
      end

      def categories
        self.class.load_agents_categories(self)
        @categories
      end

      def self.load_related_agents(agent)
        q = Goo.sparql_query_client.select(:id, :agent).distinct.from(LinkedData::Models::OntologySubmission.uri_type).where([:id, :property, :agent])
        q = q.filter(OntologySubmission.agents_attr_uris.map{|attr| "?property = <#{attr}>"}.join(' || '))
        q = q.values(:id,  *agent.usages.keys.map { |uri| RDF::URI(uri.to_s)})
        relatedAgentsIds = q.each_solution.group_by{|x| x[:agent].to_s}
                            .reject { |agent_id, _| agent_id == agent.id.to_s }
                            .transform_values { |solutions| solutions.map { |s| s[:id] } }
        # map the previously fetched usages
        relatedAgents = self.fetch_agents_data(relatedAgentsIds.keys).each { |agent| agent.usages = relatedAgentsIds[agent.id.to_s].map(&:to_s).uniq }
        
        agent.instance_variable_set("@relatedAgents", relatedAgents)
        agent.loaded_attributes.add(:relatedAgents)
      end     
      
      def relatedAgents
        self.class.load_related_agents(self) if !instance_variable_defined?("@relatedAgents")  
        @relatedAgents
      end

      def self.load_affiliated_agents(agent)
        return nil unless agent.agentType == 'organization'
        q = Goo.sparql_query_client.select(:id).distinct.from(LinkedData::Models::Agent.uri_type)
        q = q.where([:id, LinkedData::Models::Agent.attribute_uri(:affiliations), :agent])
        q = q.values(:agent,  *agent.id)
        
        affiliatedAgentsIds = q.solutions.map { |solution| solution[:id].to_s }.uniq
        affiliatedAgents = self.fetch_agents_data(affiliatedAgentsIds) 

        
        agent.instance_variable_set("@affiliatedAgents", affiliatedAgents)
        agent.loaded_attributes.add(:affiliatedAgents)

      end     
      
      def affiliatedAgents
        self.class.load_affiliated_agents(self) if !instance_variable_defined?("@affiliatedAgents")
        @affiliatedAgents
      end

      def unique_identifiers(inst, attr)
        inst.bring(attr) if inst.bring?(attr)
        identifiers = inst.send(attr)
        return [] if identifiers.nil? || identifiers.empty?


        query =  LinkedData::Models::Agent.where(identifiers: identifiers.first)
        identifiers.drop(0).each do |i|
          query = query.or(identifiers: i)
        end
        existent_agents = query.include(:name).all
        existent_agents = existent_agents.reject{|a| a.id.eql?(inst.id)}
        return [:unique_identifiers, "`identifiers` already used by other agents: " + existent_agents.map{|x| x.name}.join(', ')] unless existent_agents.empty?
        []
      end
      def is_organization(inst, attr)
        inst.bring(attr) if inst.bring?(attr)
        affiliations = inst.send(attr)

        Array(affiliations).each do |aff|
          aff.bring(:agentType) if aff.bring?(:agentType)
          return  [:is_organization, "`affiliations` must contain only agents of type Organization"] unless aff.agentType&.eql?('organization')
        end

        []
      end
      def self.fetch_agents_data(affiliated_agents_ids)
        return [] if affiliated_agents_ids.empty?

        agent_ids = affiliated_agents_ids.map(&:to_s).uniq

        q = Goo.sparql_query_client
          .select(:id, :name, :acronym, :agentType)
          .distinct
          .from(LinkedData::Models::Agent.uri_type)
          .where(
            [:id, LinkedData::Models::Agent.attribute_uri(:name), :name],
            [:id, LinkedData::Models::Agent.attribute_uri(:agentType), :agentType]
          )
          .optional([:id, LinkedData::Models::Agent.attribute_uri(:acronym), :acronym])
          .values(:id, *agent_ids.map { |uri| RDF::URI(uri.to_s) })

        q.solutions.map do |agent|
          LinkedData::Models::Agent.read_only(
            id: agent[:id].to_s,
            name: agent[:name].to_s,
            acronym: agent[:acronym].to_s,
            agentType: agent[:agentType].to_s,
            usages: nil
          )
        end
      end

      def self.strip_submission_id_from_uris(uris)
        uris.map do |uri|
          cleaned_uri = uri.to_s.sub(%r{/submissions/\d+$}, '')
          RDF::URI(cleaned_uri)
        end
      end
    end
  end
end
