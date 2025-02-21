module LinkedData
    module Concerns
        module SemanticArtefact
            module AttributeFetcher
                def bring(*attributes)
                    attributes = [attributes] unless attributes.is_a?(Array)
                
                    attributes.each do |attr|
                        
                        mapping = self.class.attribute_mappings[attr]
                        next if mapping.nil?
                
                        model = mapping[:model]
                        mapped_attr = mapping[:attribute]
                
                        case model
                        when :ontology
                            fetch_from_ontology(attr, mapped_attr)
                        when :ontology_submission
                            fetch_from_submission(attr, mapped_attr)
                        when :metric
                            fetch_from_metrics(attr, mapped_attr)
                        end
                    end
                end
            
                private
            
                def fetch_from_ontology(attr, mapped_attr)
                    @ontology.bring(*mapped_attr)
                    self.send("#{attr}=", @ontology.send(mapped_attr)) if @ontology.respond_to?(mapped_attr)
                end
            
                def fetch_from_submission(attr, mapped_attr)
                    latest = defined?(@ontology) ? @ontology.latest_submission(status: :ready) : @submission
                    return unless latest
                    latest.bring(*mapped_attr)
                    self.send("#{attr}=", latest.send(mapped_attr)) if latest.respond_to?(mapped_attr)
                end
            
                def fetch_from_metrics(attr, mapped_attr)
                    latest = defined?(@ontology) ? @ontology.latest_submission(status: :ready) : @submission
                    return unless latest
                    latest.bring(metrics: [mapped_attr])
                    metrics = latest.metrics
                    metric_value = metrics&.respond_to?(mapped_attr) ? metrics.send(mapped_attr) || 0 : 0
                    self.send("#{attr}=", metric_value)
                end
            end
        end
    end
end