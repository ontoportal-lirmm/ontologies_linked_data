module LinkedData
  module Models
    class Affiliation < LinkedData::Models::Base
      AFFILIATION_IDENTIFIER_SCHEMES = { ISNI: 'https://isni.org/', ROR: 'https://ror.org/', GRID:'https://www.grid.ac/' }
      model :affiliation, name_with: lambda { |cc| uuid_uri_generator(cc) }
      attribute :affiliationIdentifierScheme, enforce: [:existence], enforcedValues: AFFILIATION_IDENTIFIER_SCHEMES.keys
      attribute :affiliationIdentifier, enforce: [:existence]
      attribute :affiliation, enforce: [:existence]
      attribute :acronym
      attribute :homepage, enforce: [:uri]

      attribute :schemeURI, handler: :scheme_uri_infer

      embedded true


      def scheme_uri_infer
        self.bring(:affiliationIdentifierScheme) if self.bring?(:affiliationIdentifierScheme)
        AFFILIATION_IDENTIFIER_SCHEMES[self.affiliationIdentifierScheme.to_sym] if self.affiliationIdentifierScheme
      end

    end
  end
end
