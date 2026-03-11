module LinkedData
  module Models
    class Project < LinkedData::Models::Base
      model :project, :name_with => :acronym
      attribute :acronym, enforce: [:unique, :existence, :validate_acronym]
      attribute :creator, enforce: [:existence, :user, :list]
      attribute :created, enforce: [:date_time], :default => lambda {|x| DateTime.now }
      attribute :updated, enforce: [:date_time], :default => lambda {|x| DateTime.now }
      attribute :name, enforce: [:existence]
      attribute :homePage, enforce: [:uri, :existence]
      attribute :description, enforce: [:existence]
      attribute :contacts
      attribute :institution
      attribute :ontologyUsed, enforce: [:ontology, :list]

      def validate_acronym(inst, attr)
        inst.bring(attr) if inst.bring?(attr)
        acronym = inst.send(attr)
        return acronym&.match?(/^[a-zA-Z0-9][a-zA-Z0-9_-]{1,18}[a-zA-Z0-9]$/) ? [] : [:validate_acronym, "`acronym` must be 3-20 characters, start and end with a letter or number, and may include _, or -"]
      end
    end
  end
end

