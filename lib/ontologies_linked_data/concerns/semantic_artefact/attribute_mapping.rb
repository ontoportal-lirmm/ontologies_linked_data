module LinkedData
    module Concerns
        module AttributeMapping
            def self.included(base)
                base.extend ClassMethods
            end
        
            module ClassMethods
                attr_accessor :attribute_mappings
        
                def attribute_mapped(name, **options)
                    mapped_to = options.delete(:mapped_to)
                    attribute(name, **options)
                    @attribute_mappings ||= {}
                    mapped_to[:attribute] ||= name if mapped_to
                    @attribute_mappings[name] = mapped_to if mapped_to
                end

                def type_uri
                    namespace[model_name].to_s
                end
            end
        end
    end
end