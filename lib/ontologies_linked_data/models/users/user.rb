require 'bcrypt'
require 'securerandom'
require 'ontologies_linked_data/models/users/authentication'
require 'ontologies_linked_data/models/users/role'
require 'ontologies_linked_data/models/users/subscription'
require 'ontologies_linked_data/models/users/oauth_authentication'

module LinkedData
  module Models
    class User < LinkedData::Models::Base
      include BCrypt
      include LinkedData::Models::Users::Authentication
      include LinkedData::Models::Users::OAuthAuthentication
      include LinkedData::Concerns::Analytics

      ANALYTICS_REDIS_FIELD = "user_analytics"
      PAGES_ANALYTICS_REDIS_FIELD = "pages_analytics"

      attr_accessor :show_apikey

      model :user, name_with: :username
      attribute :username, enforce: [:unique, :existence]
      attribute :email, enforce: [:unique, :existence]
      attribute :role, enforce: [:role, :list], :default => lambda {|x| [LinkedData::Models::Users::Role.default]}
      attribute :firstName
      attribute :lastName
      attribute :subscribed, default: false
      attribute :githubId, enforce: [:unique]
      attribute :orcidId, enforce: [:unique]
      attribute :created, enforce: [:date_time], :default => lambda { |record| DateTime.now }
      attribute :passwordHash, enforce: [:existence]
      attribute :apikey, enforce: [:unique], :default => lambda {|x| SecureRandom.uuid}
      attribute :subscription, enforce: [:list, :subscription]
      attribute :customOntology, enforce: [:list, :ontology]
      attribute :resetToken
      attribute :resetTokenExpireTime
      attribute :provisionalClasses, inverse: { on: :provisional_class, attribute: :creator }
      attribute :createdOntologies, enforce: [:list], handler: :load_created_ontologies

      # Hypermedia settings
      embed :subscription
      embed_values :role => [:role]
      serialize_default :username, :email, :role, :apikey
      serialize_never :passwordHash, :show_apikey, :resetToken, :resetTokenExpireTime
      serialize_filter lambda {|inst| show_apikey?(inst)}

      link_to LinkedData::Hypermedia::Link.new("createdOntologies", lambda {|s| "users/#{s.id.split('/').last}/ontologies"}, nil)

      # Cache
      cache_timeout 3600

      # Access control
      write_access :dup

      def self.show_apikey?(inst)
        # This could get called when we have an instance (serialization)
        # or when we are asking which attributes to load (controller)
        if inst.show_apikey
          return attributes
        else
          return attributes - [:apikey]
        end
      end

      def embedded_doc
        "#{self.firstName} #{self.lastName} #{self.username}"
      end

      def initialize(attributes = {})
        # Don't allow passwordHash to be set here
        attributes.delete(:passwordHash)

        # If we found a password, create a hash
        if attributes.key?(:password)
          new_password = attributes.delete(:password)
          super(attributes)
          self.password = new_password
        else
          super(attributes)
        end
        self
      end

      def save(*args)
        # Reset ontology cache if user changes their custom set
        if LinkedData.settings.enable_http_cache && self.modified_attributes.include?(:customOntology)
          Ontology.cache_collection_invalidate
          OntologySubmission.cache_collection_invalidate
        end

        if args.first&.dig(:send_notifications)
          begin
            LinkedData::Utils::Notifications.new_user(self)
          rescue StandardError => e
            puts "Error on user creation notification: #{e.message}"
          end
        end

        super
      end

      def load_created_ontologies
        ontologies = []
        q = Goo.sparql_query_client.select(:id, :acronym, :administeredBy).distinct
              .from(Ontology.uri_type)
              .where(
                [:id, LinkedData::Models::Ontology.attribute_uri(:administeredBy), :administeredBy],
                [:id, LinkedData::Models::Ontology.attribute_uri(:acronym), :acronym],
              )
              .filter("?administeredBy = <#{self.id}>")
        acronyms = q.execute.map { |o| o.acronym.to_s }
        return ontologies if acronyms.empty?
        filter_by_acronym = Goo::Filter.new(:acronym).regex(acronyms.join('|'))
        ontologies = Ontology.where.include(Ontology.goo_attrs_to_load([:all])).filter(filter_by_acronym).all
        return ontologies
      end

      def admin?
        return false unless persistent?
        bring(role: [:role])
        return false if role.empty?
        role.map {|r| r.role}.include?(LinkedData::Models::Users::Role::ADMIN)
      end

      def password=(new_password)
        @password = Password.create(new_password)
        set_passwordHash(@password)
      end

      def custom_ontology_id_set
        Set.new(self.customOntology.map {|o| o.id.to_s})
      end

      def to_s
        if bring?(:username)
          self.id.to_s
        else
          self.username.to_s
        end
      end
      def self.analytics_redis_key
        ANALYTICS_REDIS_FIELD
      end

      def self.page_visits_analytics
        load_data(PAGES_ANALYTICS_REDIS_FIELD)
      end

      private

      def set_passwordHash(password)
        self.passwordHash = password
      end

    end
  end
end
