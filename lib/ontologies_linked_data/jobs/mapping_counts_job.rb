module LinkedData
  module Jobs
    class MappingCountsJob < LinkedData::Jobs::Base
      def perform(options = {})
        acronyms = options["acronyms"] || []
        logger = Sidekiq.logger
        
        begin
          logger.info("Starting MappingCountsJob for #{acronyms.empty? ? 'all ontologies' : acronyms.join(', ')}...")
          LinkedData::Mappings.create_mapping_counts(logger, acronyms)
          logger.info("Finished MappingCountsJob successfully.")
        rescue Exception => e
          logger.error("Error in MappingCountsJob: #{e.message}\n#{e.backtrace.join("\n")}")
          raise e
        end
      end
    end
  end
end
