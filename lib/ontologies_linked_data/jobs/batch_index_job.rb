require 'ontologies_linked_data/config/config'

module LinkedData
  module Jobs
    class BatchIndexJob < LinkedData::Jobs::Base

      class ModelNotFoundError < NonRetryableError; end
      class ModelNotIndexableError < NonRetryableError; end

      def perform(model_name)
        raise InvalidParameterError, 'model_name parameter is required' if model_name.blank?

        model = Goo.model_by_name(model_name.to_sym)
        raise ModelNotIndexableError, "#{model_name} is not indexable" if model.nil? || !model.index_enabled?

        batch_index(model)
      end

      private
      def batch_index(model)
        all_attrs = get_attributes_to_include([:all], model)
        collections = model.where.include(all_attrs).all

        indexed = []
        not_indexed = []
        collections.each do |m|
          begin
            response = m.index.dig('responseHeader', 'status')
            if response.eql?(0)
              indexed << m.id
            else
              not_indexed << m.id
              logger.error "Failed to index: #{m.id} - status: #{response}"
            end
          rescue StandardError => e
            not_indexed << m.id
            logger.error "Error indexing #{m.id}: #{e.message}"
            raise e
          end
          if (indexed.size % 100).zero?
            logger.info "Successfully indexed #{indexed.size} out of #{collections.size} for the model: #{model}"
          end
        end
      end

      def get_attributes_to_include(includes_param, klass)
        ld = klass.goo_attrs_to_load(includes_param)
        ld.delete(:properties)
        ld
      end
    end
  end
end
