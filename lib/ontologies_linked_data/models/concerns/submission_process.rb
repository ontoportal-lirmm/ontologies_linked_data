module LinkedData
  module Concerns
    module SubmissionProcessable

      def process_submission(logger, options = {})
        LinkedData::Services::OntologyProcessor.new(self).process(logger, options)
      end

      def generate_missing_labels(logger)
        puts 'Start generate_mission_label'
        time = Benchmark.realtime do
          LinkedData::Services::GenerateMissingLabels.new(self).process(logger, file_path: self.master_file_path)
        end
        puts "generate_mission_label ended in #{time}"
      end

      def generate_obsolete_classes(logger)
        puts 'Start submission_obsolete_classes'
        time = Benchmark.realtime do
          LinkedData::Services::ObsoleteClassesGenerator.new(self).process(logger, file_path: self.master_file_path)
        end
        puts "submission_obsolete_classes ended in #{time}"
      end

      def extract_metadata(logger, options = {})
        puts 'Start extract metadata'
        time = Benchmark.realtime do
          LinkedData::Services::SubmissionMetadataExtractor.new(self).process(logger, options)
        end
        puts "Extract metadata ended in #{time}"
      end

      def diff(logger, older)
        puts 'Start diff'
        time = Benchmark.realtime do
          LinkedData::Services::SubmissionDiffGenerator.new(self).diff(logger, older)
        end
        puts "Diff ended in #{time}"
      end

      def generate_diff(logger)
        puts 'Start diff'
        time = Benchmark.realtime do
          LinkedData::Services::SubmissionDiffGenerator.new(self).process(logger)
        end
        puts "Diff ended in #{time}"
      end

      def index_terms(logger, commit: true, optimize: true)
        puts 'Start index terms'
        time = Benchmark.realtime do
          LinkedData::Services::OntologySubmissionIndexer.new(self).process(logger, commit: commit, optimize: optimize)
        end
        puts "Index terms ended in #{time}"
      end

      def index_properties(logger, commit: true, optimize: true)
        puts 'Start index properties'
        time = Benchmark.realtime do
          LinkedData::Services::SubmissionPropertiesIndexer.new(self).process(logger, commit: commit, optimize: optimize)
        end
        puts "Index properties ended in #{time}"
      end

      def archive
        puts 'Start archive'
        time = Benchmark.realtime do
          LinkedData::Services::OntologySubmissionArchiver.new(self).process
        end
        puts "Archive ended in #{time}"
      end

      def generate_rdf(logger, reasoning: true)
        puts 'Start generate RDF'
        time = Benchmark.realtime do
          LinkedData::Services::SubmissionRDFGenerator.new(self).process(logger, reasoning: reasoning)
        end
        puts "Generate RDF ended in #{time}"
      end

      def generate_metrics(logger)
        puts 'Start generate metrics'
        time = Benchmark.realtime do
          LinkedData::Services::SubmissionMetricsCalculator.new(self).process(logger)
        end
        puts "Generate metrics ended in #{time}"
      end

    end
  end
end

