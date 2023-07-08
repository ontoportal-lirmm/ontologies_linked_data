module LinkedData
  module Models
    class Creator < LinkedData::Models::Base
      model :creator, name_with: lambda { |c| uuid_uri_generator(c) }
      attribute :nameType, default: lambda { |_| "Personal"}, enforcedValues: %w[Organizational Personal]
      attribute :givenName
      attribute :familyName
      attribute :creatorName, enforce: [:existence]
      attribute :creatorIdentifiers, enforce: [:creator_identifier, :list]
      attribute :affiliations, enforce: [:affiliation, :list]
      attribute :email
      embedded true
      embed :creatorIdentifiers, :affiliations
    end
  end
end
