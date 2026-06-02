require 'omni_logger'

module LinkedData::Utils
  class MultiLogger < OmniLogger
    def flush
      @loggers.each(&:flush)
    end

    # OmniLogger's generated level methods broadcast with `logger.send(level, args)`,
    # passing the args as a single array (so `info("msg")` logs `["msg"]`). Redefine
    # them here to splat the args and forward the block to each underlying logger.
    Logger::Severity.constants.each do |level|
      name = level.downcase
      define_method(name) do |*args, &block|
        @loggers.each { |logger| logger.send(name, *args, &block) }
      end
    end
  end
end
