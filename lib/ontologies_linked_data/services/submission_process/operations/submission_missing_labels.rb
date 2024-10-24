module LinkedData
  module Services

    class GenerateMissingLabels < OntologySubmissionProcess
      def process(logger, options = {})
        handle_missing_labels(options[:file_path], logger)
      end

      private

      def handle_missing_labels(file_path, logger)
        callbacks = {
          include_languages: true,
          missing_labels: {
            op_name: 'Missing Labels Generation',
            required: true,
            status: LinkedData::Models::SubmissionStatus.find('RDF_LABELS').first,
            artifacts: {
              file_path: file_path
            },
            caller_on_pre: :generate_missing_labels_pre,
            caller_on_pre_page: :generate_missing_labels_pre_page,
            caller_on_each: :generate_missing_labels_each,
            caller_on_post_page: :generate_missing_labels_post_page,
            caller_on_post: :generate_missing_labels_post
          }
        }

        raw_paging = LinkedData::Models::Class.in(@submission).include(:prefLabel, :synonym, :label)
        loop_classes(logger, raw_paging, @submission, callbacks)
      end

      def process_callbacks(logger, callbacks, action_name)
        callbacks.delete_if do |_, callback|
          begin
            if callback[action_name]
              callable = self.method(callback[action_name])
              yield(callable, callback)
            end
            false
          rescue Exception => e
            logger.error("#{e.class}: #{e.message}\n#{e.backtrace.join("\n\t")}")
            logger.flush

            if callback[:status]
              @submission.add_submission_status(callback[:status].get_error_status)
              @submission.save
            end

            # halt the entire processing if :required is set to true
            raise e if callback[:required]
            # continue processing of other callbacks, but not this one
            true
          end
        end
      end

      def loop_classes(logger, raw_paging, submission, callbacks)
        page = 1
        size = 2500
        count_classes = 0
        acr = submission.id.to_s.split("/")[-1]

        # include all languages in attributes of classes if asked for
        incl_lang = callbacks.delete(:include_languages)
        RequestStore.store[:requested_lang] = :ALL if incl_lang

        operations = callbacks.values.map { |v| v[:op_name] }.join(", ")

        time = Benchmark.realtime do
          paging = raw_paging.page(page, size)
          cls_count_set = false
          cls_count = submission.class_count(logger)

          if cls_count > -1
            # prevent a COUNT SPARQL query if possible
            paging.page_count_set(cls_count)
            cls_count_set = true
          else
            cls_count = 0
          end

          iterate_classes = false
          # 1. init artifacts hash if not explicitly passed in the callback
          # 2. determine if class-level iteration is required
          callbacks.each { |_, callback| callback[:artifacts] ||= {};
          iterate_classes = true if callback[:caller_on_each] }

          process_callbacks(logger, callbacks, :caller_on_pre) {
            |callable, callback| callable.call(callback[:artifacts], logger, paging) }

          page_len = -1
          prev_page_len = -1

          begin
            t0 = Time.now
            page_classes = paging.page(page, size).all
            total_pages = page_classes.total_pages
            page_len = page_classes.length

            # nothing retrieved even though we're expecting more records
            if total_pages.positive? && page_classes.empty? && (prev_page_len == -1 || prev_page_len == size)
              j = 0
              num_calls = LinkedData.settings.num_retries_4store

              while page_classes.empty? && j < num_calls do
                j += 1
                logger.error("Empty page encountered. Retrying #{j} times...")
                sleep(2)
                page_classes = paging.page(page, size).all
                unless page_classes.empty?
                  logger.info("Success retrieving a page of #{page_classes.length} classes after retrying #{j} times...")
                end
              end

              if page_classes.empty?
                msg = "Empty page #{page} of #{total_pages} persisted after retrying #{j} times. #{operations} of #{acr} aborted..."
                logger.error(msg)
                raise msg
              end
            end

            if page_classes.empty?
              if total_pages.positive?
                logger.info("The number of pages reported for #{acr} - #{total_pages} is higher than expected #{page - 1}. Completing #{operations}...")
              else
                logger.info("Ontology #{acr} contains #{total_pages} pages...")
              end
              break
            end

            prev_page_len = page_len
            logger.info("#{acr}: page #{page} of #{total_pages} - #{page_len} ontology terms retrieved in #{Time.now - t0} sec.")
            logger.flush
            count_classes += page_classes.length

            process_callbacks(logger, callbacks, :caller_on_pre_page) {
              |callable, callback| callable.call(callback[:artifacts], logger, paging, page_classes, page) }

            page_classes.each { |c|
              process_callbacks(logger, callbacks, :caller_on_each) {
                |callable, callback| callable.call(callback[:artifacts], logger, paging, page_classes, page, c) }
            } if iterate_classes

            process_callbacks(logger, callbacks, :caller_on_post_page) {
              |callable, callback| callable.call(callback[:artifacts], logger, paging, page_classes, page) }
            cls_count += page_classes.length unless cls_count_set

            page = page_classes.next? ? page + 1 : nil
          end while !page.nil?

          callbacks.each { |_, callback| callback[:artifacts][:count_classes] = cls_count }
          process_callbacks(logger, callbacks, :caller_on_post) {
            |callable, callback| callable.call(callback[:artifacts], logger, paging) }
        end

        logger.info("Completed #{operations}: #{acr} in #{time} sec. #{count_classes} classes.")
        logger.flush

        # set the status on actions that have completed successfully
        callbacks.each do |_, callback|
          if callback[:status]
            @submission.add_submission_status(callback[:status])
            @submission.save
          end
        end
        RequestStore.store[:requested_lang] = nil if incl_lang
      end

      def generate_missing_labels_pre(artifacts = {}, logger, paging)
        file_path = artifacts[:file_path]
        artifacts[:save_in_file] = File.join(File.dirname(file_path), "labels.ttl")
        artifacts[:save_in_file_mappings] = File.join(File.dirname(file_path), "mappings.ttl")
        property_triples = LinkedData::Utils::Triples.rdf_for_custom_properties(@submission)
        Goo.sparql_data_client.append_triples(@submission.id, property_triples, mime_type = "application/x-turtle")
        fsave = File.open(artifacts[:save_in_file], "w")
        fsave.write(property_triples)
        fsave_mappings = File.open(artifacts[:save_in_file_mappings], "w")
        artifacts[:fsave] = fsave
        artifacts[:fsave_mappings] = fsave_mappings
      end

      def generate_missing_labels_pre_page(artifacts = {}, logger, paging, page_classes, page)
        artifacts[:label_triples] = []
        artifacts[:mapping_triples] = []
      end

      def generate_missing_labels_each(artifacts = {}, logger, paging, page_classes, page, c)
        pref_label = nil
        portal_lang = Goo.portal_language
        pref_label_lang = c.prefLabel(include_languages: true)
        no_default_pref_label = pref_label_lang.nil? || (pref_label_lang.keys & [portal_lang, :none, '@none']).empty?

        if no_default_pref_label
          lang_rdfs_labels = c.label(include_languages: true)

          # Set lang_rdfs_labels to { none: [] } if empty or no match for default label
          if Array(lang_rdfs_labels).empty? || (lang_rdfs_labels.keys & [portal_lang, :none, '@none']).empty?
            lang_rdfs_labels = { none: [] }
          end

          lang_rdfs_labels.each do |lang, rdfs_labels|
            # Remove synonyms from rdfs_labels if there are multiple labels and synonyms exist
            if rdfs_labels&.length.to_i > 1 && c.synonym.present?
              rdfs_labels = (Set.new(c.label) - Set.new(c.synonym)).to_a.first || c.label
            end

            # Ensure rdfs_labels is an array
            rdfs_labels = Array(rdfs_labels) if rdfs_labels && !rdfs_labels.is_a?(Array)

            # Select the label: either the minimal sorted label or the last fragment of the IRI
            label = rdfs_labels&.min || LinkedData::Utils::Triples.last_iri_fragment(c.id.to_s)

            # Set language to nil for :none and assign pref_label
            lang = nil if lang.eql?(:none) || lang.to_s.eql?('@none')
            pref_label = label if lang.nil? || lang.eql?(portal_lang)
            pref_label ||= label

            artifacts[:label_triples] << LinkedData::Utils::Triples.label_for_class_triple(
              c.id, Goo.vocabulary(:metadata_def)[:prefLabel], pref_label, lang
            )
          end
        elsif pref_label_lang
          pref_label = c.prefLabel
        else
          pref_label = LinkedData::Utils::Triples.last_iri_fragment(c.id.to_s)
        end

        # Handle loom transformation if ontology is not a view
        unless @submission.ontology.viewOf
          loom_label = LinkedData::Models::OntologySubmission.loom_transform_literal(pref_label.to_s)

          if loom_label.length > 2
            artifacts[:mapping_triples] << LinkedData::Utils::Triples.loom_mapping_triple(
              c.id, Goo.vocabulary(:metadata_def)[:mappingLoom], loom_label
            )
          end

          artifacts[:mapping_triples] << LinkedData::Utils::Triples.uri_mapping_triple(
            c.id, Goo.vocabulary(:metadata_def)[:mappingSameURI], c.id
          )
        end

      end

      def generate_missing_labels_post_page(artifacts = {}, logger, paging, page_classes, page)
        rest_mappings = LinkedData::Mappings.migrate_rest_mappings(@submission.ontology.acronym)
        artifacts[:mapping_triples].concat(rest_mappings)

        if artifacts[:label_triples].length.positive?
          logger.info("Asserting #{artifacts[:label_triples].length} labels in " +
                        "#{@submission.id.to_ntriples}")
          logger.flush
          artifacts[:label_triples] = artifacts[:label_triples].join("\n")
          artifacts[:fsave].write(artifacts[:label_triples])
          t0 = Time.now
          Goo.sparql_data_client.append_triples(@submission.id, artifacts[:label_triples], mime_type = "application/x-turtle")
          t1 = Time.now
          logger.info("Labels asserted in #{t1 - t0} sec.")
          logger.flush
        else
          logger.info("No labels generated in page #{page}.")
          logger.flush
        end

        if artifacts[:mapping_triples].length.positive?
          logger.info("Asserting #{artifacts[:mapping_triples].length} mappings in " +
                        "#{@submission.id.to_ntriples}")
          logger.flush
          artifacts[:mapping_triples] = artifacts[:mapping_triples].join("\n")
          artifacts[:fsave_mappings].write(artifacts[:mapping_triples])

          t0 = Time.now
          Goo.sparql_data_client.append_triples(@submission.id, artifacts[:mapping_triples], mime_type = "application/x-turtle")
          t1 = Time.now
          logger.info("Mapping labels asserted in #{t1 - t0} sec.")
          logger.flush
        end
      end

      def generate_missing_labels_post(artifacts = {}, logger, pagging)
        logger.info("end generate_missing_labels traversed #{artifacts[:count_classes]} classes")
        logger.info("Saved generated labels in #{artifacts[:save_in_file]}")
        artifacts[:fsave].close()
        artifacts[:fsave_mappings].close()
        logger.flush
      end

    end

  end
end
