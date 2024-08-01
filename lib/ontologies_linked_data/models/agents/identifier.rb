module LinkedData
  module Models
    # An agent (eg. person, group, software or physical artifact)
    class AgentIdentifier < LinkedData::Models::Base
      IDENTIFIER_SCHEMES = { ORCID: 'https://orcid.org/', ISNI: 'https://isni.org/', ROR: 'https://ror.org/', GRID: 'https://www.grid.ac/' }.freeze

      model :Identifier, namespace: :adms, name_with: lambda {  |i| generate_identifier(i.notation, i.schemaAgency)}

      attribute :notation, namespace: :skos, enforce: %i[existence valid_orcid_ror]
      attribute :schemaAgency, namespace: :adms, enforcedValues: IDENTIFIER_SCHEMES.keys, enforce: [:existence]
      attribute :schemeURI, handler: :scheme_uri_infer
      attribute :creator, type: :user, enforce: [:existence]

      embedded true

      write_access :creator
      access_control_load :creator

      def self.generate_identifier(notation, schema_agency)
        out = [schema_agency , notation].reject(&:nil?).reject(&:empty?)
        return RDF::URI.new(Goo.id_prefix + 'Identifiers/' + out.join(':')) if out.size.eql?(2)
      end

      def embedded_doc
        "#{self.id.split('/').last}"
      end

      def valid_orcid_ror(inst,attr)
        inst.bring(attr) if inst.bring?(attr)
        notation = inst.send(attr)
        return  notation&.start_with?('invalid') ? ["The indentifier you entered is invalid"]  : []
      end

      def scheme_uri_infer
        self.bring(:schemaAgency) if self.bring?(:schemaAgency)
        IDENTIFIER_SCHEMES[self.schemaAgency.to_sym] if self.schemaAgency
      end

    end

  end
end
