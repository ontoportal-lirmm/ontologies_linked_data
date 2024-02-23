module LinkedData
  module Concerns
    module OntologySubmission
      module IndexAllData
        def update_doc(doc, property, value)
          existent_prop = doc["#{property}_t"] || doc["#{property}_txt"]
          if existent_prop || value.is_a?(Array)
            doc.delete("#{property}_t")
            doc["#{property}_txt"] = Array(existent_prop) + Array(value).map(&:to_s)
          else
            doc["#{property}_t"] = value.to_s
          end
          doc
        end

        def inti_search_collection(ontology)
          conn = Goo.init_search_connection(:ontology_data)

          begin
            conn.delete_by_query("ontology_t:#{ontology}")
            conn
          rescue StandardError => e
            puts e.message
          end
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
              resource_id: sol[:id]
            }

            if sol[:id].to_s.eql?('http://opendata.inrae.fr/thesaurusINRAE/c_0015b5e0')
              puts "#{sol.to_a.join(' ')} \n"
            end

            property = sol[:p]
            value = sol[:v]

            if property.to_s.eql?(RDF.type.to_s)
              update_doc(doc, 'type', value)
            else
              update_doc(doc, property, value)
            end

            ids[sol[:id]] = doc
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

          already_indexed.each_slice(1000) do |indexed|
            new_to_index += fetch_index_documents(indexed, conn)
          end

          conn.index_document(new_to_index, commit: false)

          new_to_index.size
        end

        require 'net/http'
        require 'json'

        def post_to_solr(solr_url, collection_name, query_params)
          uri = ::URI.parse("#{solr_url}/#{collection_name}/select")

          http = Net::HTTP.new(uri.host, uri.port)
          request = Net::HTTP::Post.new(uri.request_uri)
          request.set_form_data(query_params)

          response = http.request(request)

          if response.is_a?(Net::HTTPSuccess)
            JSON.parse(response.body)
          else
            puts "Error: #{response.code} - #{response.message}"
            nil
          end
        end

        def fetch_index_documents(indexed, conn)
          indexed = indexed.to_h
          response = post_to_solr(Goo.search_conf, 'ontology_data',
                                  fq: indexed.keys.map { |x| "resource_id:\"#{x}\"" }.join(' OR '),
                                  rows: indexed.size)

          response['response']['docs'].each do |old_doc|
            id = old_doc['resource_id']

            old_doc.each do |k, v|
              next if %w[submission_id_t ontology_t].include?(k)

              if k.end_with?('_t')
                prop = k.split('_t').first.gsub('___', '://').gsub('_', '/')
              elsif k.end_with?('_txt')
                prop = k.split('_txt').first.gsub('___', '://').gsub('_', '/')
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
          size = 1000
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
          time = 0
          while count_ids != old_count
            old_count = count_ids
            time += Benchmark.realtime do
              count = fetch_triples(ids, ontology, page, size, all_ids)
              logger.info("Fetched #{count} triples of #{id} page: #{page} in #{time} sec.")
              count_ids += count
            end

            time += Benchmark.realtime do
              if ids.size >= 100
                index_ids(ids, indexed_ids, conn)
                conn.index_commit
                index_ids = ids.size
                ids = {}
              end
            end

            total_time += time
            page += 1

            next unless index_ids.positive?

            logger.info("Index #{index_ids} ids of #{id} in #{time} sec. Total #{all_ids.size} ids.")
            time = 0
            index_ids = 0
          end

          unless ids.empty?
            time += Benchmark.realtime do
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






