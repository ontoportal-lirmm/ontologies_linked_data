require 'benchmark'
require 'tmpdir'

module LinkedData
  module Mappings
    OUTSTANDING_LIMIT = 30

    extend LinkedData::Concerns::Mappings::Creator
    extend LinkedData::Concerns::Mappings::BulkLoad
    extend LinkedData::Concerns::Mappings::Count

    def self.mapping_predicates
      predicates = {}
      predicates["CUI"] = ["http://bioportal.bioontology.org/ontologies/umls/cui"]
      predicates["SAME_URI"] =
        ["http://data.bioontology.org/metadata/def/mappingSameURI"]
      predicates["LOOM"] =
        ["http://data.bioontology.org/metadata/def/mappingLoom"]
      predicates["REST"] =
        ["http://data.bioontology.org/metadata/def/mappingRest"]
      return predicates
    end

    def self.internal_mapping_predicates
      predicates = {}
      predicates["SKOS:EXACT_MATCH"] = ["http://www.w3.org/2004/02/skos/core#exactMatch"]
      predicates["SKOS:CLOSE_MATCH"] = ["http://www.w3.org/2004/02/skos/core#closeMatch"]
      predicates["SKOS:BROAD_MATH"] = ["http://www.w3.org/2004/02/skos/core#broadMatch"]
      predicates["SKOS:NARROW_MATH"] = ["http://www.w3.org/2004/02/skos/core#narrowMatch"]
      predicates["SKOS:RELATED_MATH"] = ["http://www.w3.org/2004/02/skos/core#relatedMatch"]

      return predicates
    end

    def self.handle_triple_store_downtime(logger = nil)
      epr = Goo.sparql_query_client(:main)
      status = epr.status

      if status[:exception]
        logger.info(status[:exception]) if logger
        exit(1)
      end

      if status[:outstanding] > OUTSTANDING_LIMIT
        logger.info("The triple store number of outstanding queries exceeded #{OUTSTANDING_LIMIT}. Exiting...") if logger
        exit(1)
      end
    end


    def self.mapping_ontologies_count(sub1, sub2, reload_cache = false)
      sub1 = if sub1.instance_of?(LinkedData::Models::OntologySubmission)
               sub1.id
             else
               sub1
             end
      template = <<-eos
{
  GRAPH <#{sub1.to_s}> {
      ?s1 <predicate> ?o .
  }
  GRAPH graph {
      ?s2 <predicate> ?o .
  }
}
      eos
      group_count = sub2.nil? ? {} : nil
      count = 0
      latest_sub_ids = self.retrieve_latest_submission_ids
      epr = Goo.sparql_query_client(:main)

      mapping_predicates().each do |_source, mapping_predicate|
        block = template.gsub("predicate", mapping_predicate[0])
        query_template = <<-eos
      SELECT variables
      WHERE {
      block
      filter
      } group
        eos
        query = query_template.sub("block", block)
        filter = _source == "SAME_URI" ? '' : 'FILTER (?s1 != ?s2)'

        if sub2.nil?
          if sub1.to_s != LinkedData::Models::ExternalClass.graph_uri.to_s
            ont_id = sub1.to_s.split("/")[0..-3].join("/")
            #STRSTARTS is used to not count older graphs
            filter += "\nFILTER (!STRSTARTS(str(?g),'#{ont_id}'))"
          end
          query = query.sub("graph", "?g")
          query = query.sub("filter", filter)
          query = query.sub("variables", "?g (count(?s1) as ?c)")
          query = query.sub("group", "GROUP BY ?g")
        else
          query = query.sub("graph", "<#{sub2.id.to_s}>")
          query = query.sub("filter", filter)
          query = query.sub("variables", "(count(?s1) as ?c)")
          query = query.sub("group", "")
        end

        graphs = [sub1, LinkedData::Models::MappingProcess.type_uri]
        graphs << sub2.id unless sub2.nil?

        if sub2.nil?
          solutions = epr.query(query, graphs: graphs, reload_cache: reload_cache)

          solutions.each do |sol|
            graph2 = sol[:g].to_s
            acr = ""
            if graph2.start_with?(LinkedData::Models::InterportalClass.graph_base_str) || graph2 == LinkedData::Models::ExternalClass.graph_uri.to_s
              acr = graph2
            else
              acr = graph2.to_s.split("/")[-3]
            end
            if group_count[acr].nil?
              group_count[acr] = 0
            end
            group_count[acr] += sol[:c].object
          end
        else
          solutions = epr.query(query,
                                graphs: graphs)
          solutions.each do |sol|
            count += sol[:c].object
          end
        end
      end #per predicate query

      if sub2.nil?
        return group_count
      end
      return count
    end

    def self.empty_page(page, size)
      p = Goo::Base::Page.new(page, size, nil, [])
      p.aggregate = 0
      return p
    end

    def self.mappings_ontologies(sub1, sub2, page, size, classId = nil, reload_cache = false)
      sub1, acr1 = extract_acronym(sub1)
      sub2, acr2 = extract_acronym(sub2)


      mappings = []
      persistent_count = 0

      if classId.nil?
        persistent_count = count_mappings(acr1, acr2)
        return LinkedData::Mappings.empty_page(page, size) if persistent_count == 0
      end

      query = mappings_ont_build_query(classId, page, size, sub1, sub2)
      epr = Goo.sparql_query_client(:main)
      graphs = [sub1]
      unless sub2.nil?
        graphs << sub2
      end
      solutions = epr.query(query, graphs: graphs, reload_cache: reload_cache)

      s1 = nil
      s1 = RDF::URI.new(classId.to_s) unless classId.nil?

      solutions.each do |sol|
        graph2 = sub2.nil? ? sol[:g] : sub2
        s1 = sol[:s1]  if classId.nil?

        backup_mapping = nil
        if sol[:source].to_s == "REST"
          backup_mapping = LinkedData::Models::RestBackupMapping
                             .find(sol[:o]).include(:process, :class_urns).first
          backup_mapping.process.bring_remaining
        end

        classes = get_mapping_classes_instance(s1.to_s, sub1.to_s, sol[:s2].to_s, graph2, backup_mapping)

        mapping = if backup_mapping.nil?
                    LinkedData::Models::Mapping.new(classes, sol[:source].to_s)
                  else
                    LinkedData::Models::Mapping.new(
                      classes, sol[:source].to_s,
                      backup_mapping.process, backup_mapping.id)
                  end

        mappings << mapping
      end

      if size == 0
        return mappings
      end
      page = Goo::Base::Page.new(page, size, persistent_count, mappings)
      return page
    end

    def self.mappings_ontology(sub, page, size, classId = nil, reload_cache = false)
      return self.mappings_ontologies(sub, nil, page, size, classId = classId,
                                      reload_cache = reload_cache)
    end

    def self.read_only_class(classId, submissionId)
      ontologyId = submissionId
      acronym = nil
      unless submissionId['submissions'].nil?
        ontologyId = submissionId.split('/')[0..-3]
        acronym = ontologyId.last
        ontologyId = ontologyId.join('/')
      else
        acronym = ontologyId.split('/')[-1]
      end
      ontology = LinkedData::Models::Ontology
                   .read_only(
                     id: RDF::IRI.new(ontologyId),
                     acronym: acronym)
      submission = LinkedData::Models::OntologySubmission
                     .read_only(
                       id: RDF::IRI.new(ontologyId + "/submissions/latest"),
                       # id: RDF::IRI.new(submissionId),
                       ontology: ontology)
      mappedClass = LinkedData::Models::Class
                      .read_only(
                        id: RDF::IRI.new(classId),
                        submission: submission,
                        urn_id: LinkedData::Models::Class.urn_id(acronym, classId))
      return mappedClass
    end

    def self.migrate_rest_mappings(acronym)
      mappings = LinkedData::Models::RestBackupMapping
                   .where.include(:uuid, :class_urns, :process).all
      if mappings.length == 0
        return []
      end
      triples = []

      rest_predicate = mapping_predicates()["REST"][0]
      mappings.each do |m|
        m.class_urns.each do |u|
          u = u.to_s
          if u.start_with?("urn:#{acronym}")
            class_id = u.split(":")[2..-1].join(":")
            triples <<
              " <#{class_id}> <#{rest_predicate}> <#{m.id}> . "
          end
        end
      end
      return triples
    end

    def self.delete_rest_mapping(mapping_id)
      mapping = get_rest_mapping(mapping_id)
      if mapping.nil?
        return nil
      end
      rest_predicate = mapping_predicates()["REST"][0]
      classes = mapping.classes
      classes.each do |c|
        if c.respond_to?(:submission)
          sub = c.submission
          unless sub.id.to_s["latest"].nil?
            #the submission in the class might point to latest
            sub = LinkedData::Models::Ontology.find(c.submission.ontology.id)
                                              .first
                                              .latest_submission
          end
          del_from_graph = sub.id
        elsif c.respond_to?(:source)
          # If it is an InterportalClass
          del_from_graph = LinkedData::Models::InterportalClass.graph_uri(c.source)
        else
          # If it is an ExternalClass
          del_from_graph = LinkedData::Models::ExternalClass.graph_uri
        end
        graph_delete = RDF::Graph.new
        graph_delete << [RDF::URI.new(c.id), RDF::URI.new(rest_predicate), mapping.id]
        Goo.sparql_update_client.delete_data(graph_delete, graph: del_from_graph)
      end
      mapping.process.delete
      backup = LinkedData::Models::RestBackupMapping.find(mapping_id).first
      unless backup.nil?
        backup.delete
      end
      return mapping
    end

    # A method that generate classes depending on the nature of the mapping : Internal, External or Interportal
    def self.get_mapping_classes_instance(c1, g1, c2, g2, backup)
      external_source = nil
      external_ontology = nil
      # Generate classes if g1 is interportal or external
      if g1.start_with?(LinkedData::Models::InterportalClass.graph_base_str)
        backup.class_urns.each do |class_urn|
          # get source and ontology from the backup URI from 4store (source(like urn):ontology(like STY):class)
          unless class_urn.start_with?("urn:")
            external_source = class_urn.split(":")[0]
            external_ontology = get_external_ont_from_urn(class_urn, prefix: external_source)
          end
        end
        classes = [LinkedData::Models::InterportalClass.new(c1, external_ontology, external_source),
                   read_only_class(c2, g2)]
      elsif g1 == LinkedData::Models::ExternalClass.graph_uri.to_s
        backup.class_urns.each do |class_urn|
          unless class_urn.start_with?("urn:")
            external_ontology = get_external_ont_from_urn(class_urn)
          end
        end
        classes = [LinkedData::Models::ExternalClass.new(c1, external_ontology),
                   read_only_class(c2, g2)]

        # Generate classes if g2 is interportal or external
      elsif g2.start_with?(LinkedData::Models::InterportalClass.graph_base_str)
        backup.class_urns.each do |class_urn|
          unless class_urn.start_with?("urn:")
            external_source = class_urn.split(':')[0]
            external_ontology = get_external_ont_from_urn(class_urn, prefix: external_source)
          end
        end
        classes = [read_only_class(c1, g1),
                   LinkedData::Models::InterportalClass.new(c2, external_ontology, external_source)]
      elsif g2 == LinkedData::Models::ExternalClass.graph_uri.to_s
        if backup.nil?
          external_ontology = c2.split('/')[0..-2].join('/')
        else
          backup.class_urns.each do |class_urn|
            unless class_urn.start_with?("urn:")
              external_ontology = get_external_ont_from_urn(class_urn)
            end
          end
        end

        classes = [read_only_class(c1, g1),
                   LinkedData::Models::ExternalClass.new(c2, external_ontology)]

      else
        classes = [read_only_class(c1, g1),
                   read_only_class(c2, g2)]
      end

      return classes
    end

    # A function only used in ncbo_cron. To make sure all triples that link mappings to class are well deleted (use of metadata/def/mappingRest predicate)
    def self.delete_all_rest_mappings_from_sparql
      rest_predicate = mapping_predicates()["REST"][0]
      actual_graph = ""
      count = 0
      qmappings = <<-eos
SELECT DISTINCT ?g ?class_uri ?backup_mapping
WHERE {
  GRAPH ?g {
    ?class_uri <#{rest_predicate}> ?backup_mapping .
  }
}
      eos
      epr = Goo.sparql_query_client(:main)
      epr.query(qmappings).each do |sol|
        if actual_graph == sol[:g].to_s && count < 4000
          # Trying to delete more than 4995 triples at the same time cause a memory error. So 4000 by 4000. Or until we met a new graph
          graph_delete << [RDF::URI.new(sol[:class_uri].to_s), RDF::URI.new(rest_predicate), RDF::URI.new(sol[:backup_mapping].to_s)]
        else
          if count == 0
          else
            Goo.sparql_update_client.delete_data(graph_delete, graph: RDF::URI.new(actual_graph))
          end
          graph_delete = RDF::Graph.new
          graph_delete << [RDF::URI.new(sol[:class_uri].to_s), RDF::URI.new(rest_predicate), RDF::URI.new(sol[:backup_mapping].to_s)]
          count = 0
          actual_graph = sol[:g].to_s
        end
        count = count + 1
      end
      if count > 0
        Goo.sparql_update_client.delete_data(graph_delete, graph: RDF::URI.new(actual_graph))
      end
    end

    def self.get_external_ont_from_urn(urn, prefix: 'ext')
      urn.to_s[/#{prefix}:(.*):(http.*)/, 1]
    end

    def self.get_rest_mapping(mapping_id)
      backup = LinkedData::Models::RestBackupMapping.find(mapping_id).include(:class_urns).first
      if backup.nil?
        return nil
      end
      rest_predicate = mapping_predicates()["REST"][0]
      qmappings = <<-eos
SELECT DISTINCT ?s1 ?c1 ?s2 ?c2 ?uuid ?o
WHERE {
  ?uuid <http://data.bioontology.org/metadata/process> ?o .
  GRAPH ?s1 {
    ?c1 <#{rest_predicate}> ?uuid .
  }
  GRAPH ?s2 {
    ?c2 <#{rest_predicate}> ?uuid .
  }
FILTER(?uuid = <#{LinkedData::Models::Base.replace_url_prefix_to_id(mapping_id)}>)
FILTER(?s1 != ?s2)
} LIMIT 1
      eos
      epr = Goo.sparql_query_client(:main)
      graphs = [LinkedData::Models::MappingProcess.type_uri]
      mapping = nil
      epr.query(qmappings,
                graphs: graphs).each do |sol|

        classes = get_mapping_classes_instance(sol[:c1].to_s, sol[:s1].to_s, sol[:c2].to_s, sol[:s2].to_s, backup)

        process = LinkedData::Models::MappingProcess.find(sol[:o]).first
        process.bring_remaining unless process.nil?
        mapping = LinkedData::Models::Mapping.new(classes, "REST",
                                                  process,
                                                  sol[:uuid])
      end
      mapping
    end

    def self.check_mapping_exist(cls, relations_array)
      class_urns = generate_class_urns(cls)
      mapping_exist = false
      qmappings = <<-eos
SELECT DISTINCT ?uuid ?urn1 ?urn2 ?p
WHERE {
  ?uuid <http://data.bioontology.org/metadata/class_urns> ?urn1 .
  ?uuid <http://data.bioontology.org/metadata/class_urns> ?urn2 .
  ?uuid <http://data.bioontology.org/metadata/process> ?p .
FILTER(?urn1 = <#{class_urns[0]}>)
FILTER(?urn2 = <#{class_urns[1]}>)
} LIMIT 10
      eos
      epr = Goo.sparql_query_client(:main)
      graphs = [LinkedData::Models::MappingProcess.type_uri]
      epr.query(qmappings,
                graphs: graphs).each do |sol|
        process = LinkedData::Models::MappingProcess.find(sol[:p]).include(:relation).first
        process_relations = process.relation.map { |r| r.to_s }
        relations_array = relations_array.map { |r| r.to_s }
        if process_relations.sort == relations_array.sort
          mapping_exist = true
          break
        end
      end
      return mapping_exist
    end

    def self.mappings_for_classids(class_ids, sources = ["REST", "CUI"])

      class_ids = class_ids.uniq
      predicates = {}
      sources.each do |t|
        predicates[mapping_predicates()[t][0]] = t
      end
      qmappings = <<-eos
SELECT DISTINCT ?s1 ?c1 ?s2 ?c2 ?pred
WHERE {
  GRAPH ?s1 {
    ?c1 ?pred ?o .
  }
  GRAPH ?s2 {
    ?c2 ?pred ?o .
  }
FILTER(?s1 != ?s2)
FILTER(filter_pred)
FILTER(filter_classes)
}
      eos
      qmappings = qmappings.gsub("filter_pred",
                                 predicates.keys.map { |x| "?pred = <#{x}>" }.join(" || "))
      qmappings = qmappings.gsub("filter_classes",
                                 class_ids.map { |x| "?c1 = <#{x}>" }.join(" || "))
      epr = Goo.sparql_query_client(:main)
      graphs = [LinkedData::Models::MappingProcess.type_uri]
      mappings = []
      epr.query(qmappings,
                graphs: graphs).each do |sol|
        classes = [read_only_class(sol[:c1].to_s, sol[:s1].to_s),
                   read_only_class(sol[:c2].to_s, sol[:s2].to_s)]
        source = predicates[sol[:pred].to_s]
        mappings << LinkedData::Models::Mapping.new(classes, source)
      end
      return mappings
    end

    def self.recent_rest_mappings(n)
      graphs = [LinkedData::Models::MappingProcess.type_uri]
      qdate = <<-eos
SELECT DISTINCT ?s
FROM <#{LinkedData::Models::MappingProcess.type_uri}>
WHERE { ?s <http://data.bioontology.org/metadata/date> ?o }
ORDER BY DESC(?o) LIMIT #{n}
      eos
      epr = Goo.sparql_query_client(:main)
      procs = []
      epr.query(qdate, graphs: graphs, query_options: { rules: :NONE }).each do |sol|
        procs << sol[:s]
      end
      if procs.length == 0
        return []
      end
      graphs = [LinkedData::Models::MappingProcess.type_uri]
      proc_object = Hash.new
      LinkedData::Models::MappingProcess.where
                                        .include(LinkedData::Models::MappingProcess.attributes)
                                        .all.each do |obj|
        #highly cached query
        proc_object[obj.id.to_s] = obj
      end
      procs = procs.map { |x| "?o = #{x.to_ntriples}" }.join " || "
      rest_predicate = mapping_predicates()["REST"][0]
      qmappings = <<-eos
SELECT DISTINCT ?ont1 ?c1 ?s1 ?ont2 ?c2 ?s2 ?o ?uuid
WHERE {
  ?uuid <http://data.bioontology.org/metadata/process> ?o .
  OPTIONAL { ?s1 <http://data.bioontology.org/metadata/ontology> ?ont1 . }
  GRAPH ?s1 {
    ?c1 <#{rest_predicate}> ?uuid .
  }
  OPTIONAL { ?s2 <http://data.bioontology.org/metadata/ontology> ?ont2 . }
  GRAPH ?s2 {
    ?c2 <#{rest_predicate}> ?uuid .
  }
FILTER(?ont1 != ?ont2)
FILTER(?c1 != ?c2)
FILTER (#{procs})
}
      eos
      epr = Goo.sparql_query_client(:main)
      mappings = []
      epr.query(qmappings,
                graphs: graphs, query_options: { rules: :NONE }).each do |sol|

        if sol[:ont1].nil?
          # if the 1st class is from External or Interportal we don't want it to be in the list of recent, it has to be in 2nd
          next
        else
          ont1 = sol[:ont1].to_s
        end
        ont2 = if sol[:ont2].nil?
                 sol[:s2].to_s
               else
                 sol[:ont2].to_s
               end

        mapping_id = RDF::URI.new(sol[:uuid].to_s)
        backup = LinkedData::Models::RestBackupMapping.find(mapping_id).include(:class_urns).first
        classes = get_mapping_classes_instance(sol[:c1].to_s, ont1, sol[:c2].to_s, ont2, backup)

        process = proc_object[sol[:o].to_s]
        mapping = LinkedData::Models::Mapping.new(classes, "REST",
                                                  process,
                                                  sol[:uuid])
        mappings << mapping
      end
      mappings.sort_by { |x| x.process.date }.reverse[0..n - 1]
    end

    def self.retrieve_latest_submission_ids(options = {})
      include_views = options[:include_views] || false
      ids_query = <<-eos
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
SELECT (CONCAT(xsd:string(?ontology), "/submissions/", xsd:string(MAX(?submissionId))) as ?id)
WHERE { 
	?id <http://data.bioontology.org/metadata/ontology> ?ontology .
	?id <http://data.bioontology.org/metadata/submissionId> ?submissionId .
	?id <http://data.bioontology.org/metadata/submissionStatus> ?submissionStatus .
	?submissionStatus <http://data.bioontology.org/metadata/code> "RDF" . 
	include_views_filter 
}
GROUP BY ?ontology
      eos
      include_views_filter = include_views ? '' : <<-eos
	OPTIONAL { 
		?id <http://data.bioontology.org/metadata/ontology> ?ontJoin .  
	} 
	OPTIONAL { 
		?ontJoin <http://data.bioontology.org/metadata/viewOf> ?viewOf .  
	} 
	FILTER(!BOUND(?viewOf))
      eos
      ids_query.gsub!("include_views_filter", include_views_filter)
      epr = Goo.sparql_query_client(:main)
      solutions = epr.query(ids_query)
      latest_ids = {}

      solutions.each do |sol|
        acr = sol[:id].to_s.split("/")[-3]
        latest_ids[acr] = sol[:id].object
      end

      latest_ids
    end

    def self.retrieve_latest_submissions(options = {})
      acronyms = (options[:acronyms] || [])
      status = (options[:status] || "RDF").to_s.upcase
      include_ready = status.eql?("READY") ? true : false
      status = "RDF" if status.eql?("READY")
      any = status.eql?("ANY")
      include_views = options[:include_views] || false

      submissions_query = if any
                            LinkedData::Models::OntologySubmission.where
                          else
                            LinkedData::Models::OntologySubmission.where(submissionStatus: [code: status])
                          end
      submissions_query = submissions_query.filter(Goo::Filter.new(ontology: [:viewOf]).unbound) unless include_views
      submissions = submissions_query.include(:submissionStatus, :submissionId, ontology: [:acronym]).to_a
      submissions.select! { |sub| acronyms.include?(sub.ontology.acronym) } unless acronyms.empty?
      latest_submissions = {}

      submissions.each do |sub|
        next if include_ready && !sub.ready?
        latest_submissions[sub.ontology.acronym] ||= sub
        latest_submissions[sub.ontology.acronym] = sub if sub.submissionId > latest_submissions[sub.ontology.acronym].submissionId
      end
      return latest_submissions
    end


    private
    def self.mappings_ont_build_query(class_id, page, size, sub1, sub2)
      blocks = []
      mapping_predicates.each do |_source, mapping_predicate|
        blocks << mappings_union_template(class_id, sub1, sub2,
                                          mapping_predicate[0],
                                          "BIND ('#{_source}' AS ?source)")
      end






      filter = class_id.nil? ? "FILTER ((?s1 != ?s2) || (?source = 'SAME_URI'))" : ''
      if sub2.nil?
        class_id_subject = class_id.nil? ? '?s1' :  "<#{class_id.to_s}>"
        source_graph = sub1.nil? ? '?g' :  "<#{sub1.to_s}>"
        internal_mapping_predicates.each do |_source, predicate|
          blocks << <<-eos
        {
          GRAPH #{source_graph} {
            #{class_id_subject} <#{predicate[0]}> ?s2 .
          }
          BIND(<http://data.bioontology.org/metadata/ExternalMappings> AS ?g)
          BIND(?s2 AS ?o)
          BIND ('#{_source}' AS ?source)
        }
          eos
        end

        ont_id = sub1.to_s.split("/")[0..-3].join("/")
        #STRSTARTS is used to not count older graphs
        #no need since now we delete older graphs

        filter += "\nFILTER (!STRSTARTS(str(?g),'#{ont_id}')"
        filter += " || " + internal_mapping_predicates.keys.map{|x| "(?source = '#{x}')"}.join('||')
        filter += ")"
      end



      variables = "?s2 #{sub2.nil? ? '?g' : ''} ?source ?o"
      variables = "?s1 " + variables if class_id.nil?




      pagination = ''
      if size > 0
        limit = size
        offset = (page - 1) * size
        pagination = "OFFSET #{offset} LIMIT #{limit}"
      end

      query = <<-eos
SELECT DISTINCT #{variables}
WHERE {
   #{blocks.join("\nUNION\n")}
   #{filter}
} #{pagination}
      eos

      query
    end

    def self.mappings_union_template(class_id, sub1, sub2, predicate, bind)
      class_id_subject = class_id.nil? ? '?s1' :  "<#{class_id.to_s}>"
      target_graph = sub2.nil? ? '?g' :  "<#{sub2.to_s}>"
      union_template = <<-eos
{
  GRAPH <#{sub1.to_s}> {
      #{class_id_subject} <#{predicate}> ?o .
  }
  GRAPH #{target_graph} {
      ?s2 <#{predicate}> ?o .
  }
  #{bind}
}
      eos
    end

    def self.count_mappings(acr1, acr2)
      count = LinkedData::Models::MappingCount.where(ontologies: acr1)
      count = count.and(ontologies: acr2) unless acr2.nil?
      f = Goo::Filter.new(:pair_count) == (not acr2.nil?)
      count = count.filter(f)
      count = count.include(:count)
      pcount_arr = count.all
      pcount_arr.length == 0 ? 0 : pcount_arr.first.count
    end

    def self.extract_acronym(submission)
      sub = submission
      if submission.nil?
        acr = nil
      elsif submission.respond_to?(:id)
        # Case where sub2 is a Submission
        sub = submission.id
        acr= sub.to_s.split("/")[-3]
      else
        acr = sub.to_s
      end

      return sub, acr
    end

  end
end