module LinkedData
  module Concerns
    module Mappings
      module Count
        def mapping_counts(enable_debug = false, logger = nil, reload_cache = false, arr_acronyms = [])
          logger = nil unless enable_debug
          t = Time.now
          latest = retrieve_latest_submissions({ acronyms: arr_acronyms })
          counts = {}
          # Counting for External mappings
          t0 = Time.now
          external_uri = LinkedData::Models::ExternalClass.graph_uri
          exter_counts = mapping_ontologies_count(external_uri, nil, reload_cache = reload_cache)
          exter_total = 0
          exter_counts.each do |k, v|
            exter_total += v
          end
          counts[external_uri.to_s] = exter_total
          logger.info("Time for External Mappings took #{Time.now - t0} sec. records #{exter_total}") if enable_debug
          LinkedData.settings.interportal_hash ||= {}
          # Counting for Interportal mappings
          LinkedData.settings.interportal_hash.each_key do |acro|
            t0 = Time.now
            interportal_uri = LinkedData::Models::InterportalClass.graph_uri(acro)
            inter_counts = mapping_ontologies_count(interportal_uri, nil, reload_cache = reload_cache)
            inter_total = 0
            inter_counts.each do |k, v|
              inter_total += v
            end
            counts[interportal_uri.to_s] = inter_total
            if enable_debug
              logger.info("Time for #{interportal_uri.to_s} took #{Time.now - t0} sec. records #{inter_total}")
            end
          end
          # Counting for mappings between the ontologies hosted by the BioPortal appliance
          i = 0
          Goo.sparql_query_client(:main)

          latest.each do |acro, sub|
            handle_triple_store_downtime(logger) if Goo.backend_4s?
            t0 = Time.now
            s_counts = mapping_ontologies_count(sub, nil, reload_cache = reload_cache)
            s_total = 0

            s_counts.each do |k, v|
              s_total += v
            end
            counts[acro] = s_total
            i += 1

            next unless enable_debug

            logger.info("#{i}/#{latest.count} " +
                          "Retrieved #{s_total} records for #{acro} in #{Time.now - t0} seconds.")
            logger.flush
          end

          if enable_debug
            logger.info("Total time #{Time.now - t} sec.")
            logger.flush
          end
          return counts
        end

        def create_mapping_counts(logger, arr_acronyms = [])
          ont_msg = arr_acronyms.empty? ? 'all ontologies' : "ontologies [#{arr_acronyms.join(', ')}]"

          time = Benchmark.realtime do
            create_mapping_count_totals_for_ontologies(logger, arr_acronyms)
          end
          logger.info("Completed rebuilding total mapping counts for #{ont_msg} in #{(time / 60).round(1)} minutes.")
          puts "create mappings total count time: #{time}"

          time = Benchmark.realtime do
            create_mapping_count_pairs_for_ontologies(logger, arr_acronyms)
          end
          puts "create mappings pair count time: #{time}"
          logger.info("Completed rebuilding mapping count pairs for #{ont_msg} in #{(time / 60).round(1)} minutes.")
        end

        def create_mapping_count_totals_for_ontologies(logger, arr_acronyms)
          new_counts = mapping_counts(true, logger, true, arr_acronyms)
          persistent_counts = {}

          LinkedData::Models::MappingCount.where(pair_count: false)
                                          .include(:ontologies, :count, :pair_count)
                                          .include(:all)
                                          .all
                                          .each do |m|
            persistent_counts[m.ontologies.first] = m
          end

          latest = retrieve_latest_submissions
          delete_zombie_mapping_count(persistent_counts, latest, new_counts)


          num_counts = new_counts.keys.length
          ctr = 0

          new_counts.each_key do |acr|
            new_count = new_counts[acr]
            ctr += 1
            update_mapping_count(persistent_counts, new_counts, acr, acr, new_count, false)
            remaining = num_counts - ctr
            logger.info("Total mapping count saved for #{acr}: #{new_count}. " << (remaining.positive? ? "#{remaining} counts remaining..." : 'All done!'))
          end
        end

        # This generates pair mapping counts for the given
        # ontologies to ALL other ontologies in the system
        def create_mapping_count_pairs_for_ontologies(logger, arr_acronyms)

          latest_submissions = retrieve_latest_submissions({ acronyms: arr_acronyms })
          all_latest_submissions = retrieve_latest_submissions
          ont_total = latest_submissions.length
          logger.info("There is a total of #{ont_total} ontologies to process...")
          ont_ctr = 0

          latest_submissions.each do |acr, sub|
            new_counts = nil

            time = Benchmark.realtime do
              new_counts = mapping_ontologies_count(sub, nil, true)
            end
            logger.info("Retrieved new mapping pair counts for #{acr} in #{time} seconds.")
            ont_ctr += 1
            persistent_counts = {}
            LinkedData::Models::MappingCount.where(pair_count: true).and(ontologies: acr)
                                            .include(:ontologies, :count).all.each do |m|
              other = m.ontologies.first
              other = m.ontologies.last if other == acr
              persistent_counts[other] = m
            end

            delete_zombie_mapping_count(persistent_counts, all_latest_submissions, new_counts)


            num_counts = new_counts.keys.length
            logger.info("Ontology: #{acr}. #{num_counts} mapping pair counts to record...")
            logger.info('------------------------------------------------')
            ctr = 0

            new_counts.each_key do |other|
              new_count = new_counts[other]
              ctr += 1
              update_mapping_count(persistent_counts, new_counts, acr, other, new_count, true)
              remaining = num_counts - ctr
              logger.info("Mapping count saved for the pair [#{acr}, #{other}]: #{new_count}. " << (remaining.positive? ? "#{remaining} counts remaining for #{acr}..." : 'All done!'))
              wait_interval = 250

              next unless (ctr % wait_interval).zero?

              sec_to_wait = 1
              logger.info("Waiting #{sec_to_wait} second" << ((sec_to_wait > 1) ? 's' : '') << '...')
              sleep(sec_to_wait)
            end
            remaining_ont = ont_total - ont_ctr
            logger.info("Completed processing pair mapping counts for #{acr}. " << (remaining_ont.positive? ? "#{remaining_ont} ontologies remaining..." : 'All ontologies processed!'))
          end
        end

        private

        def update_mapping_count(persistent_counts, new_counts, acr, other, new_count, pair_count)
          if persistent_counts.include?(other)
            inst = persistent_counts[other]
            if new_count.zero?
              inst.delete
            elsif new_count != inst.count
              inst.pair_count = true
              inst.count = new_count
              inst.save
            end
          else
            return unless new_counts.key?(other)

            m = LinkedData::Models::MappingCount.new
            m.count = new_count
            m.ontologies = if pair_count
                             [acr, other]
                           else
                             [acr]
                           end
            m.pair_count = pair_count
            m.save
          end
        end

        def delete_zombie_mapping_count(persistent_counts, all_latest_submissions, new_counts)
          persistent_counts.each do |k, v|
            next if all_latest_submissions.key?(k) && new_counts.key?(k)

            v.delete
            persistent_counts.delete(k)
          end
        end
      end
    end
  end
end
