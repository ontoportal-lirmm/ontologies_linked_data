module LinkedData
    module Concerns
        module SemanticArtefact
            module AttributeFetcher
                def bring(*attributes)
                    attributes.flatten!

                    grouped_attributes = attributes.each_with_object(Hash.new { |h, k| h[k] = {} }) do |attr, hash|
                        mapping = self.class.attribute_mappings[attr]
                        next unless mapping
                        model = mapping[:model]
                        mapped_attr = mapping[:attribute]
                        hash[model][mapped_attr] = attr
                    end

                    fetch_from_ontology(grouped_attributes[:ontology]) if grouped_attributes[:ontology].any?
                    fetch_from_submission(grouped_attributes[:ontology_submission]) if grouped_attributes[:ontology_submission].any?
                    fetch_from_metrics(grouped_attributes[:metric]) if grouped_attributes[:metric].any?
                end
            
                private
            
                def fetch_from_ontology(attributes)
                    return if attributes.empty?
                    @ontology.bring(*attributes.keys)
                    attributes.each do |mapped_attr, attr|
                        self.send("#{attr}=", @ontology.send(mapped_attr)) if @ontology.respond_to?(mapped_attr)
                    end
                end
            
                def fetch_from_submission(attributes)
                    return if attributes.empty?
                    @latest ||= defined?(@ontology) ? @ontology.latest_submission(status: :ready) : @submission
                    return unless @latest
                    @latest.bring(*attributes.keys)
                    attributes.each do |mapped_attr, attr|
                        self.send("#{attr}=", @latest.send(mapped_attr)) if @latest.respond_to?(mapped_attr)
                    end
                end
            
                def fetch_from_metrics(attributes)
                    return if attributes.empty?
                    @latest ||= defined?(@ontology) ? @ontology.latest_submission(status: :ready) : @submission
                    return unless @latest
                    @latest.bring(metrics: [attributes.keys])
                    attributes.each do |mapped_attr, attr|
                        metric_value = @latest.metrics&.respond_to?(mapped_attr) ? @latest.metrics.send(mapped_attr) || 0 : 0
                        self.send("#{attr}=", metric_value)
                    end
                end
            end
        end
    end
end