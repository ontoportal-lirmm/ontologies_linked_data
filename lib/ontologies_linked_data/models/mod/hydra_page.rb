module LinkedData
  module Models
    class HydraPage < Goo::Base::Page

      def convert_hydra_page(options, &block)
        {
          '@id': 'Collection',
          '@type': 'hydra:Collection',
          totalItems: self.aggregate,
          itemsPerPage: self.size,
          view: generate_hydra_page_view(options, self.page_number, self.total_pages),
          collection: map { |item| item.to_flex_hash(options, &block) }
        }
      end
      
      def self.generate_hydra_context
        {
          'hydra': 'http://www.w3.org/ns/hydra/core#',
          'Collection': 'hydra:Collection',
          'member': 'hydra:member',
          'totalItems': 'hydra:totalItems',
          'itemsPerPage': 'hydra:itemsPerPage',
          'view': 'hydra:view',
          'firstPage': 'hydra:first',
          'lastPage': 'hydra:last',
          'previousPage': 'hydra:previous',
          'nextPage': 'hydra:next',
        }
      end
      
      private

      def generate_hydra_page_view(options, page, page_count)
        request = options[:request]
        request_path = request ? "#{LinkedData.settings.rest_url_prefix.chomp("/")}#{request.path}" : nil
        params = request ? request.params.dup : {}

        build_url = ->(page_number) {
          query = Rack::Utils.build_nested_query(params.merge("page" => page_number.to_s))
          request_path ? "#{request_path}?#{query}" : "?#{query}"
        }

        {
          "@id": build_url.call(page),
          "@type": "hydra:PartialCollectionView",
          firstPage: build_url.call(1),
          previousPage: page > 1 ? build_url.call(page - 1) : nil,
          nextPage: page < page_count ? build_url.call(page + 1) : nil,
          lastPage: page_count != 0 ? build_url.call(page_count) : build_url.call(1)
        }
      end

    end
  end
end
