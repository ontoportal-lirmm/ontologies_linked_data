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
      embed_values affiliations: LinkedData::Models::Agent.goo_attrs_to_load + [identifiers: LinkedData::Models::AgentIdentifier.goo_attrs_to_load]
      serialize_methods :usages

      write_access :creator
      access_control_load :creator

      enable_indexing(:agents_metadata)

      def embedded_doc
        "#{self.name} #{self.acronym} #{self.email} #{self.agentType}"
      end

      def self.load_agents_usages(agents = [], agent_attributes =  OntologySubmission.agents_attr_uris)
        q = Goo.sparql_query_client.select(:id, :property, :agent, :status).distinct.from(LinkedData::Models::OntologySubmission.uri_type).where([:id,LinkedData::Models::OntologySubmission.attribute_uri(:submissionStatus),:status], [:id, :property, :agent])
        q = q.filter("?status = <#{RDF::URI.new(LinkedData::Models::SubmissionStatus.id_prefix + 'RDF')}> || ?status = <#{RDF::URI.new(LinkedData::Models::SubmissionStatus.id_prefix + 'UPLOADED')}>")
        q = q.filter(agent_attributes.map{|attr| "?property = <#{attr}>"}.join(' || '))

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
    end
  end
end
