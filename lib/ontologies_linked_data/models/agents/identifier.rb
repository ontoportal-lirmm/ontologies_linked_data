module LinkedData
  module Models
    # An agent (eg. person, group, software or physical artifact)
    class AgentIdentifier < LinkedData::Models::Base
      IDENTIFIER_SCHEMES = { ORCID: 'https://orcid.org/', ISNI: 'https://isni.org/', ROR: 'https://ror.org/', GRID: 'https://www.grid.ac/' }.freeze

      model :Identifier, namespace: :adms, name_with: lambda {  |i| generate_identifier(i.notation, i.schemaAgency)}

      attribute :notation, namespace: :skos, enforce: %i[existence no_url notation_format]
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

      def no_url(inst,attr)
        inst.bring(attr) if inst.bring?(attr)
        notation = inst.send(attr)
        return  notation&.start_with?('http') ? [:no_url, "`notation` must not be a URL"]  : []
      end

      def notation_format(inst, attr)
        inst.bring([attr, :schemaAgency]) if inst.bring?(attr)
        notation = inst.send(attr)
        schema_agency = inst.send(:schemaAgency)

        # Validate notation format depending on schema to not have weird ids
        case schema_agency
        when "ROR"
          unless notation.match?(/^[0-9a-z]{9}$/i) # ROR IDs are 9-char base32
            return [:notation_format, "`notation` must be compliant with ROR format"]
          end
        when "ORCID"
          unless notation.match?(/^\d{4}-\d{4}-\d{4}-\d{3}[\dX]$/)
            return [:notation_format, "`notation` must be compliant with ORCID format"]
          end
        when "ISNI"
          unless notation.match?(/^\d{4}\s?\d{4}\s?\d{4}\s?\d{3}[\dX]$/)
            return [:notation_format, "`notation` must be compliant with ISNI format"]
          end
        when "GRID"
          unless notation.match?(/^grid\.[0-9]+\.[a-f0-9]{1,2}$/i)
            return [:notation_format, "`notation` must be compliant with GRID format"]
          end
        end

      end

      def scheme_uri_infer
        self.bring(:schemaAgency) if self.bring?(:schemaAgency)
        IDENTIFIER_SCHEMES[self.schemaAgency.to_sym] if self.schemaAgency
      end

    end

  end
end
