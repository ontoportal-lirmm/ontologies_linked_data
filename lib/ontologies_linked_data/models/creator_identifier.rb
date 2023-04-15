module LinkedData
  module Models
    class CreatorIdentifier < LinkedData::Models::Base
      IDENTIFIER_SCHEMES = { ORCID: 'https://orcid.org', ISNI: 'https://isni.org/', ROR: 'https://ror.org/', GRID:'https://www.grid.ac/' }
      model :creator_identifier, name_with: lambda { |cc| uuid_uri_generator(cc) }
      attribute :nameIdentifierScheme, enforce: [:existence], enforcedValues: IDENTIFIER_SCHEMES.keys
      attribute :nameIdentifier, enforce: [:existence]
      attribute :schemeURI, handler: :scheme_uri_infer

      embedded true


      def scheme_uri_infer
        self.bring(:nameIdentifierScheme) if self.bring?(:nameIdentifierScheme)
        IDENTIFIER_SCHEMES[self.nameIdentifierScheme.to_sym] if self.nameIdentifierScheme
      end
    end
  end
end
