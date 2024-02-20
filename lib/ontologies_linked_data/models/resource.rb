require 'rdf/raptor'

module LinkedData
    module Models
      
        class Resource
            
            def initialize(graph, id)
                @id = id 
                @graph = graph 
                @hash = fetch_related_triples(graph, id)
            end
            
            def to_hash
                @hash
            end
            
            def to_object
                hashes = self.to_hash
                class_name = "GeneratedModel_#{Time.now.to_i}"
                
                model_schema = ::Class.new(LinkedData::Models::Base)
                Object.const_set(class_name, model_schema)

                model_schema.model(:resource, name_with: :id, rdf_type: lambda { |*x| self.to_hash[Goo.namespaces[:rdf][:type].to_s] })
                values_hash = {}
                hashes.each do |predicate, value|
                    namespace, attr = namespace_predicate(predicate)
                    next if namespace.nil?
                    model_schema.attribute(attr.to_sym, property: namespace.to_s, enforce: get_type(value))
                    values_hash[attr.to_sym] = value
                end
    
                values_hash[:id] = hashes["id"]
                model_schema.new(values_hash)
            end

            def to_json()
                LinkedData::Serializers.serialize(stringify_hash(to_hash), LinkedData::MediaTypes::JSON)
            end

            def to_xml()
                LinkedData::Serializers.serialize(stringify_hash(to_hash) ,LinkedData::MediaTypes::XML)
            end
            
            def to_ntriples()
                LinkedData::Serializers.serialize(to_hash, LinkedData::MediaTypes::NTRIPLES)
            end

            def to_turtle()
                LinkedData::Serializers.serialize(to_hash, LinkedData::MediaTypes::TURTLE)
            end


            def namespaces
                to_hash.keys.map do |x| 
                    namespace, id = namespace_predicate(x)
                    namespace
                end.compact.uniq
            end                 

            private

            def fetch_related_triples(graph, id)
                query = Goo.sparql_query_client.select(:predicate, :object)
                        .from(RDF::URI.new(graph))
                        .where([RDF::URI.new(id), :predicate, :object])
        
                hashes = {"id" => RDF::URI.new(id)}
                
                query.each_solution do |solution|
                    predicate = solution[:predicate].to_s
                    value = solution[:object]

                    if hashes[predicate]
                        if hashes[predicate].is_a?(Array)
                            hashes[predicate] << value
                        else
                            hashes[predicate] = [value, hashes[predicate]]
                        end
                    else
                        hashes[predicate] = value
                    end
                end
                # TODO add context
                return hashes
            end

            def stringify_hash(hashes)
                hashes.transform_values do |value|
                    if value.is_a?(Array)
                      value.map(&:to_s)
                    else
                      value.to_s
                    end
                end
            end

            def get_type(value)
                types = []
                types << :list if value.is_a?(Array)
                value = Array(value).first
                if value.is_a?(RDF::URI)
                    types << :uri 
                elsif value.object.is_a?(Float)
                    types << :float 
                elsif value.object.is_a?(Integer)
                    types << :integer
                elsif value.datatype.eql?(RDF::XSD.boolean)
                    types << :boolean
                end 
                types
            end 
            
            def namespace_predicate(property_url)
                regex = /^(?<namespace>.*[\/#])(?<id>[^\/#]+)$/
                match = regex.match(property_url)
                return [match[:namespace],  match[:id]] if match
            end 


        end
    end
end