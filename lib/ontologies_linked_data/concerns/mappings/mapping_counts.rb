module LinkedData
  module Concerns
    module Mappings
      module Count
        def mapping_counts(enable_debug, logger, reload_cache = false, arr_acronyms = [])
          logger = nil unless enable_debug
          start_time = Time.now
          counts = {}

          # Process External and Interportal Mappings
          counts[LinkedData::Models::ExternalClass.graph_uri.to_s] = calculate_and_log_counts(
            LinkedData::Models::ExternalClass.graph_uri, logger, reload_cache, 'External Mappings', enable_debug
          )

          LinkedData.settings.interportal_hash&.each_key do |acro|
            uri = LinkedData::Models::InterportalClass.graph_uri(acro)
            counts[uri.to_s] =
              calculate_and_log_counts(uri, logger, reload_cache, "Interportal Mappings for #{acro}", enable_debug)
          end

          # Process Hosted Ontologies
          retrieve_latest_submissions(acronyms: arr_acronyms).each_with_index do |(acro, sub), index|
            counts[acro] =
              calculate_and_log_counts(sub, logger, reload_cache, "Hosted Ontology #{acro} (#{index + 1})", enable_debug)
          end

          logger&.info("Total time #{Time.now - start_time} sec.") if enable_debug
          counts
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
          persistent_counts = all_existent_mapping_counts(pair_count: false)
          latest = retrieve_latest_submissions
          delete_zombie_submission_count(persistent_counts, latest)

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
          all_latest_submissions = retrieve_latest_submissions
          latest_submissions = if Array(arr_acronyms).empty?
                                 all_latest_submissions
                               else
                                 all_latest_submissions.select { |k, _v| arr_acronyms.include?(k) }
                               end

          ont_total = latest_submissions.length
          logger.info("There is a total of #{ont_total} ontologies to process...")
          ont_ctr = 0

          persistent_counts = all_existent_mapping_counts(pair_count: true)
          delete_zombie_submission_count(persistent_counts, all_latest_submissions)

          latest_submissions.each do |acr, sub|
            new_counts = nil

            time = Benchmark.realtime do
              new_counts = mapping_ontologies_count(sub, nil, true)
            end
            logger.info("Retrieved new mapping pair counts for #{acr} in #{time} seconds.")
            ont_ctr += 1

            persistent_counts = all_existent_mapping_counts(acr: acr, pair_count: true)
            delete_zombie_mapping_count(persistent_counts, new_counts)

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

        def calculate_and_log_counts(uri, logger, reload_cache, label, enable_debug)
          start_time = Time.now
          count = mapping_ontologies_count(uri, nil, reload_cache).values.sum
          logger&.info("#{label} took #{Time.now - start_time} sec. records #{count}") if enable_debug
          count
        end

        def update_mapping_count(persistent_counts, new_counts, acr, other, new_count, pair_count)
          if persistent_counts.key?(other)
            inst = persistent_counts[other]
            if new_count.zero? && pair_count
              inst.delete
            elsif new_count != inst.count
              inst.pair_count = pair_count
              inst.count = new_count
              inst.save
            end
          else
            return if !new_counts.key?(other) && pair_count

            m = LinkedData::Models::MappingCount.new
            m.count = new_count
            m.ontologies = if pair_count
                             [acr, other]
                           else
                             [acr]
                           end
            m.pair_count = pair_count
            return if m.exist?

            m.save
          end
        end

        def delete_zombie_mapping_count(persistent_counts, new_counts)
          persistent_counts.each do |acronym, mapping|
            next if mapping.ontologies.all? { |x| new_counts.key?(x) }

            mapping.delete
            persistent_counts.delete(acronym)
          end
        end

        def delete_zombie_submission_count(persistent_counts, all_latest_submissions)
          special_mappings = ["http://data.bioontology.org/metadata/ExternalMappings",
                              "http://data.bioontology.org/metadata/InterportalMappings/agroportal",
                              "http://data.bioontology.org/metadata/InterportalMappings/ncbo",
                              "http://data.bioontology.org/metadata/InterportalMappings/sifr"]

          persistent_counts.each do |acronym, mapping|
            next if mapping.ontologies.size == 1 && !(mapping.ontologies & special_mappings).empty?
            next if mapping.ontologies.all? { |x| all_latest_submissions.key?(x) }

            mapping.delete
            persistent_counts.delete(acronym)
          end
        end

        def all_existent_mapping_counts(acr: nil, pair_count: true)
          persistent_counts = {}
          query = LinkedData::Models::MappingCount
          query = if acr
                    query.where(ontologies: acr)
                  else
                    query.where
                  end

          f = Goo::Filter.new(:pair_count) == pair_count
          query = query.filter(f)

          query.include(:ontologies, :count).all.each do |m|
            other = m.ontologies.first
            other = m.ontologies.last if acr && (other == acr)
            persistent_counts[other] = m
          end
          persistent_counts
        end

      end
    end
  end
end
