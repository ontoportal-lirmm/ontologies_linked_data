
module LinkedData
  module Services

    class SubmissionRDFGenerator < OntologySubmissionProcess

      def process(logger, options)
        reasoning = options[:reasoning]

        # Remove processing status types before starting RDF parsing etc.
        @submission.submissionStatus = nil
        status = LinkedData::Models::SubmissionStatus.find('UPLOADED').first
        @submission.add_submission_status(status)
        @submission.save

        # Parse RDF
        begin
          unless @submission.valid?
            error = 'Submission is not valid, it cannot be processed. Check errors.'
            raise ArgumentError, error
          end
          unless @submission.uploadFilePath
            error = 'Submission is missing an ontology file, cannot parse.'
            raise ArgumentError, error
          end
          status = LinkedData::Models::SubmissionStatus.find('RDF').first
          @submission.remove_submission_status(status) # remove RDF status before starting
          generate_rdf(logger, reasoning: reasoning)
          @submission.add_submission_status(status)
          @submission.save
        rescue StandardError => e
          logger.error("#{e.class}: #{e.message}\n#{e.backtrace.join("\n\t")}")
          logger.flush
          @submission.add_submission_status(status.get_error_status)
          @submission.save
          # If RDF generation fails, no point of continuing
          raise e
        end
      end

      private

      def generate_rdf(logger, reasoning: true)
        mime_type = nil

        if @submission.hasOntologyLanguage.umls?
          triples_file_path = @submission.triples_file_path
          logger.info("UMLS turtle file found; doing OWLAPI parse to extract metrics")
          logger.flush
          mime_type = LinkedData::MediaTypes.media_type_from_base(LinkedData::MediaTypes::TURTLE)
          SubmissionMetricsCalculator.new(@submission).generate_umls_metrics_file(triples_file_path)
          delete_and_append(triples_file_path, logger, mime_type)
        elsif @submission.hasOntologyLanguage.xlsx?
          generate_rdf_from_xlsx(logger, reasoning: reasoning)
        else
          output_rdf = @submission.rdf_path

          if File.exist?(output_rdf)
            logger.info("deleting old owlapi.xrdf ..")
            deleted = FileUtils.rm(output_rdf)

            if !deleted.empty?
              logger.info("deleted")
            else
              logger.info("error deleting owlapi.rdf")
            end
          end

          owlapi = @submission.owlapi_parser(logger: logger)
          owlapi.disable_reasoner unless reasoning

          triples_file_path, missing_imports = owlapi.parse

          if missing_imports && !missing_imports.empty?
            @submission.missingImports = missing_imports

            missing_imports.each do |imp|
              logger.info("OWL_IMPORT_MISSING: #{imp}")
            end
          else
            @submission.missingImports = nil
          end
          logger.flush
          delete_and_append(triples_file_path, logger, mime_type)
        end
      end

      def generate_rdf_from_xlsx(logger, reasoning: true)
        require "ontologies_linked_data/parser/xlsx_converter"
        xlsx_path = @submission.master_file_path
        logger.info("XLSX format detected; converting to OWL via XlsxConverter")
        logger.info("XLSX path: #{xlsx_path}")
        logger.flush

        # Derive ontology_id from submission metadata
        @submission.ontology.bring(:acronym) if @submission.ontology.bring?(:acronym)
        ontology_id = @submission.ontology.acronym

        # Derive base_uri from submission URI or default
        @submission.bring(:URI) if @submission.bring?(:URI)
        base_uri = @submission.URI.to_s

        # Convert XLSX to OWL
        owl_xml = LinkedData::Parser::XlsxConverter.convert(xlsx_path, ontology_id, base_uri)

        # Write converted OWL to a temp file
        converted_owl_path = File.join(@submission.data_folder, "converted_from_xlsx.owl")
        File.write(converted_owl_path, owl_xml)
        logger.info("XLSX converted to OWL (#{owl_xml.length} bytes), written to #{converted_owl_path}")
        logger.flush

        # Feed the converted OWL to OWLAPI for parsing
        output_rdf = @submission.rdf_path
        FileUtils.rm(output_rdf) if File.exist?(output_rdf)

        owlapi = LinkedData::Parser::OWLAPICommand.new(
          converted_owl_path,
          File.expand_path(@submission.data_folder.to_s),
          logger: logger
        )
        owlapi.disable_reasoner unless reasoning

        triples_file_path, missing_imports = owlapi.parse

        if missing_imports && !missing_imports.empty?
          @submission.missingImports = missing_imports
          missing_imports.each { |imp| logger.info("OWL_IMPORT_MISSING: #{imp}") }
        else
          @submission.missingImports = nil
        end
        logger.flush

        delete_and_append(triples_file_path, logger, nil)
      end

      def delete_and_append(triples_file_path, logger, mime_type = nil)
        Goo.sparql_data_client.delete_graph(@submission.id)
        Goo.sparql_data_client.put_triples(@submission.id, triples_file_path, mime_type)
        logger.info("Triples #{triples_file_path} appended in #{@submission.id.to_ntriples}")
        logger.flush
      end
    end
  end
end
