
module LinkedData
    module Serializers
        class NTRIPLES

            def self.serialize(hashes, options = {})
                subject = RDF::URI.new(hashes["id"])
                hashes.delete("id")
                RDF::Writer.for(:ntriples).buffer(options) do |writer|
                    hashes.each do |p, o|
                        predicate = RDF::URI.new(p)
                        if o.is_a?(Array)
                            o.each do |item|
                                writer << RDF::Statement.new(subject, predicate, item)
                            end
                        else
                            writer << RDF::Statement.new(subject, predicate, o)
                        end

                    end
                end
            end

        end
    end
end
  
  