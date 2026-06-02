module LinkedData
  module Services
    class OntologyProcessor < OntologySubmissionProcess

      ################################################################
      # Possible options with their defaults:
      #   process_rdf       = false
      #   index_search      = false
      #   index_properties  = false
      #   index_commit      = false
      #   run_metrics       = false
      #   reasoning         = false
      #   diff              = false
      #   archive           = false
      #   if no options passed, ALL actions, except for archive = true
      ################################################################
      def process(logger, options = nil)
        process_submission(logger, options)
      end

      private

      def process_submission(logger, options = {})
        # Wrap the whole process so we can email results
        begin
          @submission.bring_remaining
          @submission.ontology.bring_remaining

          logger.info("Starting to process #{@submission.ontology.acronym}/submissions/#{@submission.submissionId}")
          logger.flush
          LinkedData::Parser.logger = logger

          if process_archive?(options)
            @submission.archive
          else

            @submission.generate_rdf(step_logger(logger, 'parsed.log'), reasoning: process_reasoning?(options)) if process_rdf?(options)

            parsed = @submission.ready?(status: %i[rdf])

            @submission = @submission.extract_metadata(step_logger(logger, 'metadata.log'), user_params: options[:params], heavy_extraction: extract_metadata?(options))

            @submission.generate_missing_labels(step_logger(logger, 'labels.log')) if generate_missing_labels?(options)

            @submission.generate_obsolete_classes(step_logger(logger, 'obsolete.log')) if generate_obsolete_classes?(options)

            if !parsed && (index_search?(options) || index_properties?(options) || index_all_data?(options))
              raise StandardError, "The submission #{@submission.ontology.acronym}/submissions/#{@submission.submissionId}
                                cannot be indexed because it has not been successfully parsed"
            end

            @submission.index_all(step_logger(logger, 'indexed.log'), commit: process_index_commit?(options)) if index_all_data?(options)

            @submission.index_terms(step_logger(logger, 'indexed.log'), commit: process_index_commit?(options)) if index_search?(options)

            @submission.index_properties(step_logger(logger, 'indexed.log'), commit: process_index_commit?(options)) if index_properties?(options)

            @submission.generate_metrics(step_logger(logger, 'metrics.log')) if process_metrics?(options)

            @submission.generate_diff(step_logger(logger, 'diff.log')) if process_diff?(options)
          end
          @submission.save
          logger.info("Submission processing of #{@submission.id} completed successfully")
          logger.flush
        ensure
          # make sure results get emailed
          notify_submission_processed(logger)
        end
        @submission
      end

      def notify_submission_processed(logger)
        LinkedData::Utils::Notifications.submission_processed(@submission)
      rescue StandardError => e
        logger.error("Email sending failed: #{e.message}\n#{e.backtrace.join("\n\t")}"); logger.flush
      end

      # Build a logger for a processing step that writes both to the main log
      # (the one passed into #process) and to a step-specific file located in the
      # submission's parsing_logs folder. Loggers are memoized per file name so
      # steps sharing a file (e.g. the indexers) append to the same handle.
      def step_logger(main_logger, filename)
        @step_loggers ||= {}
        @step_loggers[filename] ||= begin
          FileUtils.mkdir_p(@submission.parsing_logs_folder)
          file_logger = Logger.new(File.join(@submission.parsing_logs_folder, filename))
          LinkedData::Utils::MultiLogger.new(loggers: [main_logger, file_logger])
        end
      end

      def process_archive?(options)
        options[:archive].eql?(true)
      end

      def process_rdf?(options)
        options.empty? || options[:process_rdf].eql?(true)
      end

      def generate_missing_labels?(options)
        options[:generate_missing_labels].nil? && process_rdf?(options) || options[:generate_missing_labels].eql?(true)
      end

      def generate_obsolete_classes?(options)
        options[:generate_obsolete_classes].nil? && process_rdf?(options) || options[:generate_obsolete_classes].eql?(true)
      end
      
      def index_all_data?(options)
        options.empty? || options[:index_all_data].eql?(true)
      end

      def index_search?(options)
        options.empty? || options[:index_search].eql?(true)
      end

      def index_properties?(options)
        options.empty? || options[:index_properties].eql?(true)
      end

      def process_index_commit?(options)
        index_search?(options) || index_properties?(options) || index_all_data?(options)
      end

      def process_diff?(options)
        options.empty? || options[:diff].eql?(true)
      end

      def process_metrics?(options)
        options.empty? || options[:run_metrics].eql?(true)
      end

      def process_reasoning?(options)
        options.empty? && options[:reasoning].eql?(true)
      end

      def extract_metadata?(options)
        options.empty? || options[:extract_metadata].eql?(true)
      end

    end
  end
end
