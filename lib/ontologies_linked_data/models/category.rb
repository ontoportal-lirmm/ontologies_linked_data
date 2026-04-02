module LinkedData
  module Models
    class Category < LinkedData::Models::Base
      model :category, name_with: :acronym
      attribute :acronym, enforce: [:unique, :existence, :validate_acronym]
      attribute :name, enforce: [:existence]
      attribute :description
      attribute :created, enforce: [:date_time], default: lambda { |record| DateTime.now }
      attribute :parentCategory, enforce: [:category, :list]
      attribute :ontologies, inverse: { on: :ontology, attribute: :hasDomain }

      serialize_default :acronym, :name, :description, :created, :parentCategory, :ontologies
      cache_timeout 86400

      def validate_acronym(inst, attr)
        inst.bring(attr) if inst.bring?(attr)
        acronym = inst.send(attr)
        return acronym&.match?(/^[A-Z][A-Z0-9_-]*$/) ? [] : [:validate_acronym, "`acronym` must be uppercase letters, numbers, underscores or hyphens only and must start with a letter"]
      end

    end
  end
end
