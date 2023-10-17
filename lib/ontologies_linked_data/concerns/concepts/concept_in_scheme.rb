module LinkedData
  module Concerns
    module Concept
      module InScheme
        def self.included(base)
          base.serialize_methods :isInActiveScheme
        end

        def isInActiveScheme
          @isInActiveScheme
        end

        def inScheme?(scheme)
          self.inScheme.include?(scheme)
        end

        def load_is_in_scheme(schemes = [])
          if self.inScheme.empty?
             @isInActiveScheme =  []
          else
            @isInActiveScheme = schemes.select { |s| inScheme?(s) }
            if @isInActiveScheme.empty?
              main_scheme = self.submission.get_main_concept_scheme
              @isInActiveScheme = [main_scheme] if main_scheme
            end
          end
        end

      end
    end
  end
end
