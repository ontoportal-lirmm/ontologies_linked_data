module LinkedData
  module Models
    class Group < LinkedData::Models::Base
      model :group, name_with: :acronym
      attribute :acronym, enforce: [:unique, :existence, :validate_acronym]
      attribute :name, enforce: [:existence]
      attribute :description
      attribute :created, enforce: [:date_time], :default => lambda { |record| DateTime.now }
      attribute :ontologies, inverse: { on: :ontology, attribute: :group }

      serialize_default :acronym, :name, :description, :created, :ontologies
      cache_timeout 86400

      def validate_acronym(inst, attr)
        inst.bring(attr) if inst.bring?(attr)
        acronym = inst.send(attr)
        return acronym&.match?(/^[A-Z][A-Z0-9_-]*$/) ? [] : [:validate_acronym, "`acronym` must be uppercase letters, numbers, underscores or hyphens only and must start with a letter"]
      end
    end
  end
end