require 'rdf/raptor'

module LinkedData
    module Serializers
      class TURTLE
        def self.serialize(hashes, options = {})
            subject = RDF::URI.new(hashes["id"])
            hashes.delete("id")
            RDF::Writer.for(:turtle).buffer(options) do |writer|
                hashes.each do |p, o|
                    predicate = RDF::URI.new(p)
                    if o.is_a?(Array)
                        o.each do |item|
                            object  = item.is_a?(RDF::Literal) ? RDF::Literal.new(item) : item
                            writer << RDF::Statement.new(subject, predicate, object)
                        end
                    else
                        object  = o.is_a?(RDF::Literal) ? RDF::Literal.new(o) : o
                        writer << RDF::Statement.new(subject, predicate, object)
                    end
                end

            end
        end
      end
    end
end
  
  