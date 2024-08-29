module LinkedData
  module Models
    class PortalConfig < LinkedData::Models::Base
      model :SemanticArtefactCatalogue, namespace: :mod, name_with: :acronym
      attribute :acronym, enforce: [:unique, :existence]
      attribute :title, namespace: :dcterms, enforce: [:existence]
      attribute :color, enforce: [:existence, :valid_hash_code]
      attribute :description, namespace: :dcterms
      attribute :logo, namespace: :foaf, enforce: [:url]
      attribute :numberOfArtefacts, namespace: :mod, handler: :ontologies_count
      attribute :federated_portals
      attribute :fundedBy, enforce: [:list]

      def self.current_portal_config
        p = LinkedData::Models::PortalConfig.new

        p.acronym = LinkedData.settings.ui_name.downcase
        p.title = LinkedData.settings.title
        p.description = LinkedData.settings.description
        p.color = LinkedData.settings.color
        p.logo = LinkedData.settings.logo
        p.fundedBy = LinkedData.settings.fundedBy
        p.federated_portals = LinkedData.settings.federated_portals
        p
      end

      def ontologies_count
        if current_portal?
          LinkedData::Models::Ontology.where(viewingRestriction: 'public').count
        else
          0
        end
      end

      def self.valid_hash_code(inst, attr)
        inst.bring(attr) if inst.bring?(attr)
        str = inst.send(attr)

        unless /^#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6})$/ === str do
          return [:valid_hash_code, "Invalid hex color code: '#{str}'. Please provide a valid hex code in the format '#FFF' or '#FFFFFF'."]
        end
        end

      end
    end
  end
end

