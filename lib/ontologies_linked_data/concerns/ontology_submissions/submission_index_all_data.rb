require 'parallel'
module LinkedData
  module Concerns
    module OntologySubmission
      module IndexAllData
        def update_doc(doc, property, new_val)
          unescaped_prop = property.gsub('___', '://')

          unescaped_prop = unescaped_prop.gsub('_', '/')
          existent_val = doc["#{unescaped_prop}_t"] || doc["#{unescaped_prop}_txt"]

          if !existent_val && !property['#']
            unescaped_prop = unescaped_prop.sub(%r{/([^/]+)$}, '#\1') # change latest '/' with '#'
            existent_val = doc["#{unescaped_prop}_t"] || doc["#{unescaped_prop}_txt"]
          end

          if existent_val && new_val || new_val.is_a?(Array)
            doc.delete("#{unescaped_prop}_t")
            doc["#{unescaped_prop}_txt"] = Array(existent_val) + Array(new_val).map(&:to_s)
          elsif existent_val.nil? && new_val
            doc["#{unescaped_prop}_t"] = new_val.to_s
          end
          doc
        end

        def inti_search_collection(ontology)
          conn = Goo.init_search_connection(:ontology_data)

          begin
            conn.delete_by_query("ontology_t:\"#{ontology}\"")
          rescue StandardError => e
            puts e.message
          end
          conn
        end

        def fetch_triples(ids, ontology, page, size, all_ids)
          query = Goo.sparql_query_client.select(:id, :p, :v)
                     .distinct
                     .from(RDF::URI.new(self.id))
                     .where(%i[id p v])
                     .limit(size)
                     .offset((page - 1) * size)
          count = 0
          query.each_solution do |sol|
            count += 1
            all_ids << sol[:id].to_s
            doc = ids[sol[:id].to_s]
            doc ||= {
              id: "#{sol[:id]}_#{ontology}", submission_id_t: self.id.to_s,
              ontology_t: ontology, resource_model: self.class.model_name,
              resource_id: sol[:id].to_s
            }

            property = sol[:p].to_s
            value = sol[:v]

            if property.to_s.eql?(RDF.type.to_s)
              update_doc(doc, 'type', value)
            else
              update_doc(doc, property, value)
            end
            ids[sol[:id].to_s] = doc
          end
          count
        end

        def index_ids(ids, indexed_ids, conn)
          new_to_index = []
          already_indexed = {}
          ids.each do |k, doc|
            if indexed_ids.include?(k)
              already_indexed[k.to_s] = doc
            else
              indexed_ids << k
              new_to_index << doc
            end
          end

          conn.index_document(new_to_index, commit: false)
          new_to_index = new_to_index.size
          new_to_index += Parallel.map(already_indexed.each_slice(1000), in_threads: 10) do |indexed|
            to_index = fetch_index_documents(indexed, conn)
            conn.index_document(to_index, commit: false)
            to_index.size
          end.sum
          new_to_index
        end


        def fetch_index_documents(indexed, conn)
          indexed = indexed.to_h
          response = conn.submit_search_query('*', { fq: indexed.keys.map { |x| "resource_id:\"#{x}\"" }.join(' OR '),
                                                     rows: indexed.size })

          response['response']['docs'].each do |old_doc|
            id = old_doc['resource_id'].to_s

            old_doc.each do |k, v|
              next if %w[submission_id_t ontology_t].include?(k)

              if k.end_with?('_t')
                prop = k.split('_t').first
              elsif k.end_with?('_txt')
                prop = k.split('_txt').first
              else
                next
              end
              update_doc(indexed[id], prop, v)
            end
          end
          indexed.values
        end

        def index_all_data(logger, commit = true, optimize = true)
          page = 1
          size = 10000
          count_ids = 0
          total_time = 0
          old_count = -1
          ontology = self.bring(:ontology).ontology
                         .bring(:acronym).acronym

          conn = inti_search_collection(ontology)

          indexed_ids = Set.new
          all_ids = Set.new
          index_ids = 0
          ids = {}

          while count_ids != old_count
            old_count = count_ids
            count = 0
            time = Benchmark.realtime do
              count = fetch_triples(ids, ontology, page, size, all_ids)
            end

            logger.info("Fetched #{count} triples of #{id} page: #{page} in #{time} sec.") if count.positive?

            count_ids += count
            total_time += time

            if ids.size >= 100
              time = Benchmark.realtime do
                index_ids(ids, indexed_ids, conn)
                conn.index_commit
                index_ids = ids.size
                ids = {}
              end
              logger.info("Index #{index_ids} ids of #{id} in #{time} sec. Total #{all_ids.size} ids.")
              total_time += time
            end

            page += 1
          end

          unless ids.empty?
            time = Benchmark.realtime do
              index_ids(ids, indexed_ids, conn)
              conn.index_commit
            end
            logger.info("Index #{index_ids} ids of #{id} in #{time} sec. Total #{all_ids.size} ids.")
            total_time += time
          end
          logger.info("Completed indexing all ontology data: #{self.id} in #{total_time} sec. #{all_ids.size} ids.")
          logger.flush
        end
      end
    end
  end
end






