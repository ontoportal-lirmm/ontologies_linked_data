require 'fileutils'
require 'redis'
require 'ontologies_linked_data/models/ontology_submission'
require 'ontologies_linked_data/models/review'
require 'ontologies_linked_data/models/group'
require 'ontologies_linked_data/models/metric'
require 'ontologies_linked_data/models/category'
require 'ontologies_linked_data/models/project'
require 'ontologies_linked_data/models/skos/scheme'
require 'ontologies_linked_data/models/skos/collection'
require 'ontologies_linked_data/models/skos/skosxl'
require 'ontologies_linked_data/models/notes/note'
require 'ontologies_linked_data/purl/purl_client'

module LinkedData
  module Models
    class Ontology < LinkedData::Models::Base
      class ParsedSubmissionError < StandardError; end
      class OntologyAnalyticsError < StandardError; end
      include LinkedData::Concerns::Analytics

      ONTOLOGY_ANALYTICS_REDIS_FIELD = "ontology_analytics"
      ONTOLOGY_RANK_REDIS_FIELD = "ontology_rank"
      DEFAULT_RANK_WEIGHT_ANALYTICS = 0.50
      DEFAULT_RANK_WEIGHT_UMLS = 0.50

      model :ontology, :name_with => :acronym
      attribute :acronym, namespace: :omv,
        enforce: [:unique, :existence, lambda { |inst,attr| validate_acronym(inst,attr) } ], fuzzy_search: true
      attribute :name, :namespace => :omv, enforce: [:unique, :existence], fuzzy_search: true
      attribute :submissions, inverse: { on: :ontology_submission, attribute: :ontology },
                metadataMappings: ["dct:hasVersion", "pav:hasCurrentVersion", "pav:hasVersion", "prov:generalizationOf", "adms:next"]
      attribute :projects,
                  inverse: { on: :project, attribute: :ontologyUsed }
      attribute :notes,
                  inverse: { on: :note, attribute: :relatedOntology }
      attribute :reviews,
                  inverse: { on: :review, attribute: :ontologyReviewed }
      attribute :provisionalClasses,
                  inverse: { on: :provisional_class, attribute: :ontology }
      attribute :subscriptions,
                  inverse: { on: :subscription, attribute: :ontology}
      attribute :administeredBy, enforce: [:existence, :user, :list], metadataMappings: ["oboInOwl:savedBy", "oboInOwl:saved-by"]
      attribute :group, enforce: [:list, :group]

      attribute :viewingRestriction, :default => lambda {|x| "public"}, metadataMappings: ["mod:accessibility"]
      attribute :doNotUpdate, enforce: [:boolean]
      attribute :flat, enforce: [:boolean]
      attribute :hasDomain, namespace: :omv, enforce: [:list, :category]
      attribute :summaryOnly, enforce: [:boolean]

      attribute :acl, enforce: [:list, :user]

      attribute :viewOf, enforce: [:ontology], onUpdate: :update_submissions_has_part
      attribute :views, :inverse => { on: :ontology, attribute: :viewOf }
      attribute :ontologyType, enforce: [:ontology_type], default: lambda { |record| LinkedData::Models::OntologyType.find("ONTOLOGY").include(:code).first }

      # Hypermedia settings
      serialize_default :administeredBy, :acronym, :name, :summaryOnly, :flat, :ontologyType, :group, :hasDomain, :viewingRestriction, :viewOf, :views
      links_load :acronym
      link_to LinkedData::Hypermedia::Link.new("submissions", lambda {|s| "ontologies/#{s.acronym}/submissions"}, LinkedData::Models::OntologySubmission.uri_type),
              LinkedData::Hypermedia::Link.new("properties", lambda {|s| "ontologies/#{s.acronym}/properties"}, "#{Goo.namespaces[:metadata].to_s}Property"),
              LinkedData::Hypermedia::Link.new("classes", lambda {|s| "ontologies/#{s.acronym}/classes"}, LinkedData::Models::Class.uri_type),
              LinkedData::Hypermedia::Link.new("single_class", lambda {|s| "ontologies/#{s.acronym}/classes/{class_id}"}, LinkedData::Models::Class.uri_type),
              LinkedData::Hypermedia::Link.new("roots", lambda {|s| "ontologies/#{s.acronym}/classes/roots"}, LinkedData::Models::Class.uri_type),
              LinkedData::Hypermedia::Link.new("schemes", lambda {|s| "ontologies/#{s.acronym}/schemes"}, LinkedData::Models::SKOS::Scheme.uri_type),
              LinkedData::Hypermedia::Link.new("collections", lambda {|s| "ontologies/#{s.acronym}/collections"}, LinkedData::Models::SKOS::Collection.uri_type),
              LinkedData::Hypermedia::Link.new("xl_labels", lambda {|s| "ontologies/#{s.acronym}/skos_xl_labels"}, LinkedData::Models::SKOS::Label.uri_type),
              LinkedData::Hypermedia::Link.new("instances", lambda {|s| "ontologies/#{s.acronym}/instances"}, Goo.vocabulary["Instance"]),
              LinkedData::Hypermedia::Link.new("metrics", lambda {|s| "ontologies/#{s.acronym}/metrics"}, LinkedData::Models::Metric.type_uri),
              LinkedData::Hypermedia::Link.new("reviews", lambda {|s| "ontologies/#{s.acronym}/reviews"}, LinkedData::Models::Review.uri_type),
              LinkedData::Hypermedia::Link.new("notes", lambda {|s| "ontologies/#{s.acronym}/notes"}, LinkedData::Models::Note.uri_type),
              LinkedData::Hypermedia::Link.new("groups", lambda {|s| "ontologies/#{s.acronym}/groups"}, LinkedData::Models::Group.uri_type),
              LinkedData::Hypermedia::Link.new("categories", lambda {|s| "ontologies/#{s.acronym}/categories"}, LinkedData::Models::Category.uri_type),
              LinkedData::Hypermedia::Link.new("latest_submission", lambda {|s| "ontologies/#{s.acronym}/latest_submission"}, LinkedData::Models::OntologySubmission.uri_type),
              LinkedData::Hypermedia::Link.new("projects", lambda {|s| "ontologies/#{s.acronym}/projects"}, LinkedData::Models::Project.uri_type),
              LinkedData::Hypermedia::Link.new("download", lambda {|s| "ontologies/#{s.acronym}/download"}, self.type_uri),
              LinkedData::Hypermedia::Link.new("views", lambda {|s| "ontologies/#{s.acronym}/views"}, self.type_uri),
              LinkedData::Hypermedia::Link.new("analytics", lambda {|s| "ontologies/#{s.acronym}/analytics"}, "#{Goo.namespaces[:metadata].to_s}Analytics"),
              LinkedData::Hypermedia::Link.new("agents", lambda {|s| "ontologies/#{s.acronym}/agents"}, LinkedData::Models::Agent.uri_type),
              LinkedData::Hypermedia::Link.new("ui", lambda {|s| "http://#{LinkedData.settings.ui_host}/ontologies/#{s.acronym}"}, self.uri_type)

      # Access control
      read_restriction lambda {|o| !o.viewingRestriction.eql?("public") }
      read_access :administeredBy, :acl
      write_access :administeredBy
      access_control_load :administeredBy, :acl, :viewingRestriction

      # Cache
      cache_timeout 3600

      enable_indexing(:ontology_metadata)

      after_save :index_latest_submission

      def self.validate_acronym(inst, attr)
        inst.bring(attr) if inst.bring?(attr)
        acronym = inst.send(attr)

        return [] if acronym.nil?

        errors = []

        if acronym.match(/\A[^a-z^A-Z]{1}/)
          errors << [:start_with_letter, "`acronym` must start with a letter"]
        end

        if acronym.match(/[a-z]/)
          errors << [:capital_letters, "`acronym` must be all capital letters"]
        end

        if acronym.match(/[^-_0-9a-zA-Z]/)
          errors << [:special_characters, "`acronym` must only contain the folowing characters: -, _, letters, and numbers"]
        end

        if acronym.match(/.{17,}/)
          errors << [:length, "`acronym` must be sixteen characters or less"]
        end

        return errors.flatten
      end

      def update_submissions_has_part(inst, attr)
        inst.bring :viewOf if inst.bring?(:viewOf)

        target_ontology = inst.viewOf

        if target_ontology.nil?
          previous_value = inst.previous_values ? inst.previous_values[attr] : nil
          return if previous_value.nil?

          action = :remove
          target_ontology = previous_value
        else
          action = :append
        end

        sub = target_ontology.latest_submission || target_ontology.bring(:submissions) && target_ontology.submissions.last

        return if sub.nil?

        sub.bring :hasPart if sub.bring?(:hasPart)

        parts = sub.hasPart.dup || []
        changed = false
        if action.eql?(:append)
          unless parts.include?(self.id)
            changed = true
            parts << self.id
          end
        elsif action.eql?(:remove)
          if parts.include?(self.id)
            changed = true
            parts.delete(self.id)
            sub.class.model_settings[:attributes][:hasPart][:enforce].delete(:include_ontology_views) #disable validator
          end
        end

        return unless changed

        sub.bring_remaining
        sub.hasPart = parts
        sub.save if sub.valid?

        return unless changed && action.eql?(:remove)

        sub.class.model_settings[:attributes][:hasPart][:enforce].append(:include_ontology_views)
      end

      def latest_submission(options = {})
        self.bring(:acronym) if self.bring?(:acronym)
        submission_id = highest_submission_id(options)
        return nil if submission_id.nil? || submission_id == 0

        self.submissions.each do |s|
          return s if s.submissionId == submission_id
        end
        nil
      end

      def submission(submission_id)
        submission_id = submission_id.to_i
        self.bring(:acronym) if self.bring?(:acronym)
        if self.loaded_attributes.include?(:submissions)
          self.submissions.each do |s|
            s.bring(:submissionId) if s.bring?(:submissionId)
            if s.submissionId == submission_id
              s.bring(:submissionStatus) if s.bring?(:submissionStatus)
              return s
            end
          end
        end
        OntologySubmission.where(ontology: [ acronym: acronym ], submissionId: submission_id.to_i)
                                .include(:submissionStatus)
                                .include(:submissionId).first
      end

      def next_submission_id
        self.bring(:submissions)
        (highest_submission_id(status: :any) || 1) + 1
      end

      def highest_submission_id(options = {})
        reload = options[:reload] || false
        status = options[:status] || :ready

        LinkedData::Models::Ontology.where.models([self])
                    .include(submissions: [:submissionId, :submissionStatus])
                    .to_a

        # TODO: this code was added to deal with intermittent issues with 4store, where
        # self.submissions was being reported as not loaded for no apparent reason
        subs = nil

        begin
          subs = self.submissions
        rescue Exception => e
          i = 0
          num_calls = LinkedData.settings.num_retries_4store
          subs = nil

          while subs.nil? && i < num_calls do
            i += 1
            puts "Exception while getting submissions for #{self.id.to_s}. Retrying #{i} times..."
            sleep(1)

            begin
              self.bring(:submissions)
              subs = self.submissions
              puts "Success getting submissions for #{self.id.to_s} after retrying #{i} times..."
            rescue Exception => e1
              subs = nil

              if i == num_calls
                puts "Exception while getting submissions for #{self.id.to_s} after retrying #{i} times: #{e1.class}: #{e1.message}\n#{e1.backtrace.join("\n")}"
              end
            end
          end
        end

        return 0 if subs.nil? || subs.empty?

        subs.each do |s|
          if !s.loaded_attributes.include?(:submissionId)
            s.bring(:submissionId)
          end
          if !s.loaded_attributes.include?(:submissionStatus)
            s.bring(:submissionStatus)
          end
        end

        # Try to get a new one based on the old
        submission_ids = []

        subs.each do |s|
          next if !s.ready?({status: status})
          submission_ids << s.submissionId.to_i
        end

        submission_ids.max
      end

      def properties(sub=nil)
        sub ||= latest_submission(status: [:rdf])
        self.bring(:acronym) if self.bring?(:acronym)
        raise ParsedSubmissionError, "The properties of ontology #{self.acronym} cannot be retrieved because it has not been successfully parsed" unless sub
        prop_classes = [LinkedData::Models::ObjectProperty, LinkedData::Models::DatatypeProperty, LinkedData::Models::AnnotationProperty]
        all_props = []

        prop_classes.each do |c|
          props = c.in(sub).include(:label, :definition, :parents).all()
          parents = []
          props.each { |p| p.load_has_children; p.parents.each {|parent| parents << parent} }
          c.in(sub).models(parents).include(:label, :definition).all()
          all_props.concat(props)
        end

        LinkedData::Models::OntologyProperty.sort_properties(all_props)
      end

      def property_roots(sub=nil, extra_include=[])
        sub ||= latest_submission(status: [:rdf])
        threshold = 99
        incl = [:label, :definition, :parents]
        incl.each { |x| extra_include.delete x }
        all_roots = []
        prop_classes = [LinkedData::Models::ObjectProperty, LinkedData::Models::DatatypeProperty, LinkedData::Models::AnnotationProperty]

        prop_classes.each do |c|
          where = c.in(sub).include(incl)
          where.include(extra_include) unless extra_include.empty?
          roots = where.all

          roots.select! { |prop|
            prop.load_has_children if extra_include.include?(:hasChildren)
            is_root = !prop.respond_to?(:parents) || prop.parents.nil? || prop.parents.empty?
            prop.loaded_attributes.delete?(:parents)
            is_root
          }

          c.partially_load_children(roots, threshold, sub) if extra_include.include?(:children)
          all_roots.concat(roots)
        end

        LinkedData::Models::OntologyProperty.sort_properties(all_roots)
      end

      def property(prop_id, sub=nil)
        p = nil
        sub ||= latest_submission(status: [:rdf])
        self.bring(:acronym) if self.bring?(:acronym)
        raise ParsedSubmissionError, "The properties of ontology #{self.acronym} cannot be retrieved because it has not been successfully parsed" unless sub
        prop_classes = [LinkedData::Models::ObjectProperty, LinkedData::Models::DatatypeProperty, LinkedData::Models::AnnotationProperty]

        prop_classes.each do |c|
          p = c.find(prop_id).in(sub).include(:label, :definition, :parents).first

          unless p.nil?
            p.load_has_children
            parents = p.parents.nil? ? [] : p.parents.dup
            c.in(sub).models(parents).include(:label, :definition).all()
            break
          end
        end

        p
      end

      # retrieve Analytics for this ontology
      def analytics(year=nil, month=nil)
        self.bring(:acronym) if self.bring?(:acronym)
        self.class.analytics(year, month, [self.acronym])
      end

      # retrieve Rank for this ontology
      def rank(weight_analytics=DEFAULT_RANK_WEIGHT_ANALYTICS, weight_umls=DEFAULT_RANK_WEIGHT_UMLS)
        self.bring(:acronym) if self.bring?(:acronym)
        self.class.rank(weight_analytics, weight_umls, [self.acronym])
      end

      # A static method for retrieving Analytics for a combination of ontologies, year, month
      def self.analytics(year=nil, month=nil, acronyms=nil)
        analytics = retrieve_analytics(year, month)
        analytics.delete_if { |acronym, _| !acronyms.include? acronym } unless acronyms.nil?
        analytics
      end

      # A static method for retrieving rank for multiple ontologies
      def self.rank(weight_analytics=DEFAULT_RANK_WEIGHT_ANALYTICS, weight_umls=DEFAULT_RANK_WEIGHT_UMLS, acronyms=nil)
        ranking = self.load_ranking_data

        unless ranking.empty?
          ranking.delete_if { |acronym, _| !acronyms.include? acronym } unless acronyms.nil?
          ranking.each { |_, rank| rank[:normalizedScore] = (weight_analytics * rank[:bioportalScore] + weight_umls * rank[:umlsScore]).round(3) }
          # sort results by the highest ranking values
          ranking = Hash[ranking.sort_by {|_, rank| rank[:normalizedScore]}.reverse]
        end
        ranking
      end

      def self.analytics_redis_key
        ONTOLOGY_ANALYTICS_REDIS_FIELD
      end

      def self.load_ranking_data
        self.load_data(ONTOLOGY_RANK_REDIS_FIELD)
      end

      ##
      # Delete all artifacts of an ontology
      def delete(*args)
        options = {}
        args.each {|e| options.merge!(e) if e.is_a?(Hash)}
        in_update = options[:in_update] || false
        index_commit = options[:index_commit] == false ? false : true

        # remove notes
        self.bring(:notes)
        self.notes.each {|n| n.delete} unless self.notes.nil?

        # remove reviews
        self.bring(:reviews)
        self.reviews.each {|r| r.delete} unless self.reviews.nil?

        # remove subscriptions
        self.bring(:subscriptions)
        self.subscriptions.each {|s| s.delete} unless self.subscriptions.nil?

        # remove references to ontology in projects
        self.bring(:projects)
        unless self.projects.nil?
          self.projects.each do |p|
            p.bring(:ontologyUsed)
            p.bring_remaining
            ontsUsed = p.ontologyUsed.dup
            ontsUsed.select! {|x| x.id != self.id}
            p.ontologyUsed = ontsUsed
            p.save()
          end
        end

        # remove references to ontology in provisional classes
        self.bring(:provisionalClasses)
        unless self.provisionalClasses.nil?
          self.provisionalClasses.each do |p|
            p.delete
          end
        end

        # remove submissions
        self.bring(:submissions)
        self.bring(:acronym) if self.bring?(:acronym)
        unless self.submissions.nil?
          self.submissions.each do |s|
            s.delete(in_update: in_update, remove_index: false)
          end
        end

        # remove views
        self.bring(:views)
        unless self.views.nil?
          self.views.each do |v|
            v.delete(in_update: in_update)
          end
        end

        # remove index entries
        unindex_all_data(index_commit)
       
        # delete all files
        ontology_dir = File.join(LinkedData.settings.repository_folder, self.acronym.to_s)
        FileUtils.rm_rf(ontology_dir)

        super(*args)
      end

      ##
      # Override save to allow creation of a PURL server entry
      def save(*args)
        super(*args)

        if (LinkedData.settings.enable_purl)
          self.bring(:acronym) if self.bring?(:acronym)
          purl_client = LinkedData::Purl::Client.new
          purl_client.create_purl(acronym)
        end
        self
      end

      def index_latest_submission
        last_s = latest_submission(status: :any)
        return if last_s.nil?

        last_s.ontology = self
        last_s.index_update([:ontology])
      end

      def unindex_all_data(commit=true)
        unindex_by_acronym(commit)
        unindex_properties(commit)
      end

      def embedded_doc
        self.administeredBy.map{|x| x.bring_remaining}
        doc = indexable_object
        doc.delete(:id)
        doc.delete(:resource_id)
        doc.delete('ontology_viewOf_resource_model_t')
        doc['ontology_viewOf_t'] = self.viewOf.id.to_s  unless self.viewOf.nil?
        doc[:resource_model_t] = doc.delete(:resource_model)
        doc
      end

      def unindex_properties(commit=true)
        self.bring(:acronym) if self.bring?(:acronym)
        query = "submissionAcronym:#{acronym}"
        OntologyProperty.unindexByQuery(query)
        OntologyProperty.indexCommit(nil) if commit
      end

      def unindex_by_acronym(commit=true)
        self.bring(:acronym) if self.bring?(:acronym)
        query = "submissionAcronym:#{acronym}"
        Class.unindexByQuery(query)
        Class.indexCommit(nil) if commit
        #OntologySubmission.clear_indexed_content(acronym)
      end

      def restricted?
        !self.viewingRestriction.eql?("public")
      end

      def accessible?(user)
        return true if user.admin?
        bring(:acl) if bring?(:acl)
        bring(:administeredBy) if bring?(:administeredBy)
        if self.restricted?
          return true
        else
          return true if self.acl.map {|u| u.id.to_s}.include?(user.id.to_s) || self.administeredBy.map {|u| u.id.to_s}.include?(user.id.to_s)
        end
        false
      end
    end
  end
end
